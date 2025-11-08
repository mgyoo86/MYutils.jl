using MYutils
using Test

@testset "MYutils.jl" begin
    @testset "analyze_specializations" begin
        # Test with Base module (should always work)
        df = analyze_specializations(Base)

        @test df isa DataFrame
        @test :name in names(df)
        @test :n_specializations in names(df)
        @test :signature in names(df)
        @test nrow(df) > 0

        # Check that specialization counts are non-negative
        @test all(>=(0), df.n_specializations)
    end
end
