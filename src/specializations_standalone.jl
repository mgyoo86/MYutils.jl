# Standalone version - can be included directly in global scope
# Usage: include("path/to/specializations_standalone.jl")

using DataFrames
using Statistics

"""
    analyze_specializations(mod::Module) -> DataFrame

Analyze method specializations for all methods in a module.
Can be used directly in global scope after including this file.
"""
function analyze_specializations(mod::Module)
    results = []

    for name in names(mod; all=true, imported=false)
        startswith(string(name), "#") && continue

        try
            obj = getfield(mod, name)

            if obj isa Function || obj isa Type
                try
                    methods_list = methods(obj)

                    for m in methods_list
                        m.module != mod && continue

                        specs = m.specializations
                        if specs !== nothing
                            spec_list = filter(!isnothing, collect(specs))
                            n_specs = length(spec_list)
                        else
                            n_specs = 0
                        end

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
                catch
                    continue
                end
            end
        catch
            continue
        end
    end

    return DataFrame(results)
end

println("✓ analyze_specializations loaded into global scope")
println("Usage: df = analyze_specializations(SomeModule)")
