"""
    analyze_specializations(mod::Module) -> DataFrame

Analyze method specializations for all methods in a module.

Returns a DataFrame with columns:
- `name`: Function/method name
- `module_name`: Module where method is defined
- `file`: Source file path
- `line`: Line number
- `signature`: Method signature
- `n_specializations`: Number of specializations
- `method_object`: The Method object (for further inspection)

# Examples
```julia
using MYutils
using IMASdd

# Analyze specializations in a module
df = analyze_specializations(IMASdd)

# Sort by number of specializations
sort!(df, :n_specializations, rev=true)

# Find methods with most specializations
first(df, 10)

# Filter methods with more than 100 specializations
filter(row -> row.n_specializations > 100, df)
```

# Tips
- Use `filter!(!isnothing, collect(method.specializations))` to get actual specialization list
- High specialization counts may indicate:
  * Missing `@nospecialize` annotations
  * `@inline` preventing specialization control
  * Type-unstable code being called with many type combinations
  * Hot paths in performance-critical code
"""
function analyze_specializations(mod::Module)
    results = []

    # Get all names in the module
    for name in names(mod; all=true, imported=false)
        # Skip internal names starting with #
        startswith(string(name), "#") && continue

        # Try to get the binding
        try
            obj = getfield(mod, name)

            # Check if it's a function
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
                            n_specs = 0
                        end

                        # Collect information
                        push!(results, (
                            name = string(name),
                            module_name = string(m.module),
                            file = string(m.file),
                            line = m.line,
                            signature = string(m.sig),
                            n_specializations = n_specs,
                            method_object = m
                        ))
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

    return DataFrame(results)
end
