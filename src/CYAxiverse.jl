"""
    CYAxiverse
A Julia package for computing axion/ALP spectra and statistics using geometric data generated by [CYTools](https://cytools.liammcallistergroup.com/).

"""
module CYAxiverse

if haskey(ENV,"newARGS")
else
    println("Please specify where to read/write data, currently using pwd!")
end
include("structs.jl")

include("filestructure.jl")
include("read.jl")
include("minimizer.jl")

include("../add_functions/profiling.jl")
if haskey(ENV, "SINGULARITY_CONTAINER")
    if occursin("CYTools",ENV["SINGULARITY_CONTAINER"])
        include("../add_functions/cytools_wrapper.jl")
    end

else
    println("This installation does not include CYTools!")
    include("init_python.jl")
    include("../jlm_python/jlm_python.jl")
end

include("generate.jl")
include("plotting.jl")

if haskey(ENV, "SLURM_JOB_ID")
    include("slurm.jl")
else
    println("This installation does not include SLURM!")
end

end
