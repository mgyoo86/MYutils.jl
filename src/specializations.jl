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
                        m.module != mod && continue

                        # Get specializations
                        specs = m.specializations
                        if specs !== nothing
                            spec_list = filter(!isnothing, collect(specs))
                            n_specs = length(spec_list)
                        else
                            spec_list = []
                            n_specs = 0
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
