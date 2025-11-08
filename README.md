# MYutils

Personal utility functions for Julia development and debugging.

## Installation

```julia
using Pkg
Pkg.develop(path="~/.julia/dev/MYutils")
```

Or in dev mode:
```julia
] dev ~/.julia/dev/MYutils
```

## Features

### Specialization Analysis

Analyze method specializations across any Julia module to identify compilation overhead.

```julia
using MYutils
using SomePackage

# Analyze specializations
df = analyze_specializations(SomePackage)

# Sort by specialization count
sort!(df, :n_specializations, rev=true)

# Show top offenders
first(df, 10)

# Filter high specialization methods
filter(row -> row.n_specializations > 100, df)

# Export to CSV
using CSV
CSV.write("specializations.csv", df)
```

**Use cases:**
- Identify compilation bottlenecks
- Find missing `@nospecialize` annotations
- Optimize package precompilation time
- Reduce latency in hot paths

## Adding New Utilities

To add new utility functions:

1. Create a new file in `src/` (e.g., `src/myfeature.jl`)
2. Include it in `src/MYutils.jl`: `include("myfeature.jl")`
3. Export public functions: `export my_function`

## License

Personal utility package - use freely.
