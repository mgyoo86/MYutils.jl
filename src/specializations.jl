"""
    analyze_specializations(mod::Module) -> DataFrame

Analyze method specializations for all methods in a module.

Returns a DataFrame with columns:
- `name`: Function/method name
- `module_name`: Module where method is defined
- `file`: Source file path
- `line`: Line number
- `signature`: Method signature
- `n_spec`: Number of specializations
- `spec_list`: List of actual specialization instances
- `method_object`: The Method object (for further inspection)

# Examples
```julia
using MYutils
using IMASdd

# Analyze specializations in a module
df = analyze_specializations(IMASdd)

# Sort by number of specializations
sort!(df, :n_spec, rev=true)

# Find methods with most specializations
first(df, 10)

# Filter methods with more than 100 specializations
filter(row -> row.n_spec > 100, df)
```

# Tips
- Access `spec_list` column to inspect actual specialization instances
- High specialization counts may indicate:
  * Missing `@nospecialize` annotations
  * `@inline` preventing specialization control
  * Type-unstable code being called with many type combinations
  * Hot paths in performance-critical code
"""
function analyze_specializations(mod::Module; sort_by_specializations=true, include_details=false)
    results = []

    # Get all names in the module
    for name in names(mod; all=true, imported=false)
        # Skip internal names starting with #
        startswith(string(name), "#") && continue

        # Try to get the binding
        try
            obj = getfield(mod, name)

            # Check if it's a function or type
            if obj isa Function || obj isa Type
                # Get all methods
                try
                    methods_list = methods(obj)

                    for m in methods_list
                        # Skip methods not defined in our module
                        if m.module != mod
                            continue
                        end

                        try
                            # Get specializations
                            specs = m.specializations
                            if specs === nothing
                                spec_list = []
                                n_specs = 0
                            elseif specs isa Core.MethodInstance
                                # Single MethodInstance (not a collection)
                                spec_list = [specs]
                                n_specs = 1
                            else
                                # Collection (SimpleVector/svec)
                                spec_list = filter(!isnothing, collect(specs))
                                n_specs = length(spec_list)
                            end

                            # Get clean method string (without ANSI color codes)
                            full_method_str = sprint(show, m, context=:color=>false)

                            # Split into signature and location parts
                            # Format: "signature @ module file:line"
                            parts = split(full_method_str, " @ ", limit=2)
                            signature_str = parts[1]
                            location_str = length(parts) > 1 ? " @ " * parts[2] : ""

                            # Column order: name, n_spec, spec_list, method, signature, location
                            row = (
                                name = string(name),
                                n_spec = n_specs,
                                spec_list = spec_list,
                                method = full_method_str,
                                signature = signature_str,
                                location = location_str,
                            )

                            # Optional detailed info (raw data)
                            if include_details
                                row = merge(row, (
                                    file = string(m.file),
                                    line = m.line,
                                    sig_raw = string(m.sig),
                                ))
                            end

                            # Always include method object at the end for programmatic access
                            row = merge(row, (method_object = m,))

                            push!(results, row)
                        catch e
                            # Skip if we can't process this method
                            continue
                        end
                    end
                catch e
                    # Some objects might not have methods
                    continue
                end
            end
        catch e
            # Skip if we can't access the binding
            continue
        end
    end

    df = DataFrame(results)

    # Sort by specializations (descending) by default
    if sort_by_specializations && nrow(df) > 0
        sort!(df, :n_spec, rev=true)
    end

    return df
end


"""
    show_wide(df::DataFrame; cols=nothing, rows=10)

Display DataFrame with wider columns (no truncation).

# Arguments
- `df`: DataFrame to display
- `cols`: Specific columns to show (default: all)
- `rows`: Number of rows to show (default: 10, use `nothing` for all)

# Examples
```julia
df = analyze_specializations(IMASdd)
show_wide(df)  # Show first 10 rows, all columns, full width
show_wide(df, cols=[:name, :n_spec, :location])  # Specific columns
show_wide(df, rows=nothing)  # All rows
```
"""
function show_wide(df::DataFrame; cols=nothing, rows=10)
    # Select columns
    df_display = isnothing(cols) ? df : df[:, cols]

    # Select rows
    if !isnothing(rows) && nrow(df_display) > rows
        df_display = first(df_display, rows)
    end

    # Display with no truncation
    show(IOContext(stdout, :displaysize => (displaysize(stdout)[1], 1000), :limit => true),
         df_display,
         allcols=true,
         truncate=0)
    println()
end


"""
    compare_specializations(df_before::DataFrame, df_after::DataFrame; verbose=true) -> DataFrame

Compare two specialization analysis DataFrames to find what changed.

Returns a DataFrame with columns:
- `name`: Function/method name
- `location`: Method location (file:line)
- `n_spec_before`: Specialization count before
- `n_spec_after`: Specialization count after
- `diff`: Difference (after - before)
- `signature`: Method signature

# Arguments
- `df_before`: DataFrame from analyze_specializations() before operation
- `df_after`: DataFrame from analyze_specializations() after operation
- `verbose`: Print summary statistics (default: true)

# Examples
```julia
using MYutils, IMASdd

# Analyze before
df_before = analyze_specializations(IMASdd)
total_before = sum(df_before.n_spec)

# Run some code that triggers compilation
some_operation()

# Analyze after
df_after = analyze_specializations(IMASdd)
total_after = sum(df_after.n_spec)

# Compare to find what changed
df_diff = compare_specializations(df_before, df_after)

# Show only methods that increased
filter(row -> row.diff > 0, df_diff)
```
"""
function compare_specializations(df_before::DataFrame, df_after::DataFrame; verbose=true)
    # Join on location (unique identifier for each method)
    df_compared = innerjoin(
        select(df_before, :name, :location, :signature, :n_spec => :n_spec_before),
        select(df_after, :location, :n_spec => :n_spec_after),
        on = :location
    )

    # Calculate difference
    df_compared[!, :diff] = df_compared.n_spec_after .- df_compared.n_spec_before

    # Sort by diff (descending)
    sort!(df_compared, :diff, rev=true)

    # Find new methods (in after but not before)
    df_new = antijoin(
        select(df_after, :name, :location, :signature, :n_spec),
        df_before,
        on = :location
    )

    if verbose
        total_before = sum(df_before.n_spec)
        total_after = sum(df_after.n_spec)
        n_increased = count(>(0), df_compared.diff)
        n_decreased = count(<(0), df_compared.diff)
        n_unchanged = count(==(0), df_compared.diff)

        println("=" ^ 80)
        println("Specialization Analysis Comparison")
        println("=" ^ 80)
        println("Total specializations:")
        println("  Before: $total_before")
        println("  After:  $total_after")
        println("  Change: $(total_after - total_before) ($(total_after > total_before ? "+" : "")$(round((total_after - total_before) / total_before * 100, digits=2))%)")
        println()
        println("Methods:")
        println("  Increased: $n_increased")
        println("  Decreased: $n_decreased")
        println("  Unchanged: $n_unchanged")
        println("  New:       $(nrow(df_new))")
        println()

        # Show top increasers
        df_increased = filter(row -> row.diff > 0, df_compared)
        if nrow(df_increased) > 0
            println("Top 5 methods with most new specializations:")
            show_wide(first(df_increased, min(5, nrow(df_increased))),
                     cols=[:name, :n_spec_before, :n_spec_after, :diff, :location])
            println()
        end

        # Show new methods if any
        if nrow(df_new) > 0
            println("Newly specialized methods ($(nrow(df_new)) total):")
            show_wide(first(df_new, min(5, nrow(df_new))),
                     cols=[:name, :n_spec, :location])
            println()
        end

        println("=" ^ 80)
    end

    return df_compared
end
