import Libdl

const depsfile = joinpath(@__DIR__, "deps.jl")

# Determine MATLAB library path and provide facilities to load libraries with
# this path

function find_matlab_homepath()
    matlab_home = get(ENV, "MATLAB_HOME", nothing)
    if isnothing(matlab_home)
        matlab_exe = Sys.which("matlab")
        matlab_home = !isnothing(matlab_exe) ? dirname(dirname(matlab_exe)) : nothing
        if isnothing(matlab_home)
            if Sys.isapple()
                default_dir = "/Applications"
                if isdir(default_dir)
                    dirs = readdir(default_dir)
                    filter!(app -> occursin(r"^MATLAB_R[0-9]+[ab]\.app$", app), dirs)
                    if !isempty(dirs)
                        matlab_home = joinpath(default_dir, maximum(dirs))
                    end
                end
            elseif Sys.iswindows()
                default_dir = Sys.WORD_SIZE == 32 ? "C:\\Program Files (x86)\\MATLAB" : "C:\\Program Files\\MATLAB"
                if isdir(default_dir)
                    dirs = readdir(default_dir)
                    filter!(dir -> occursin(r"^R[0-9]+[ab]$", dir), dirs)
                    if !isempty(dirs)
                        matlab_home = joinpath(default_dir, maximum(dirs))
                    end
                end
            end
        end
    end
    if isnothing(matlab_home)
        return nothing
    else
        @info("Found MATLAB home path at $matlab_home")
        return matlab_home
    end
end

function find_matlab_libpath(matlab_home)
    # get path to MATLAB libraries
    matlab_lib_dir = if Sys.islinux()
        Sys.WORD_SIZE == 32 ? "glnx86" : "glnxa64"
    elseif Sys.isapple()
        Sys.WORD_SIZE == 32 ? "maci" : "maci64"
    elseif Sys.iswindows()
        Sys.WORD_SIZE == 32 ? "win32" : "win64"
    end
    matlab_libpath = joinpath(matlab_home, "bin", matlab_lib_dir)
    if !isdir(matlab_libpath)
        @warn("The MATLAB library path could not be found.")
    end
    return matlab_libpath
end

function find_matlab_cmd(matlab_home)
    if !Sys.iswindows()
        matlab_cmd = joinpath(matlab_home, "bin", "matlab")
        if !isfile(matlab_cmd)
            @warn("The MATLAB path is invalid. Ensure the \"MATLAB_HOME\" evironmental variable to the MATLAB root directory.")
        end
        matlab_cmd = "exec $(Base.shell_escape(matlab_cmd))"
    elseif Sys.iswindows()
        matlab_cmd = joinpath(matlab_home, "bin", (Sys.WORD_SIZE == 32 ? "win32" : "win64"), "MATLAB.exe")
        if !isfile(matlab_cmd)
            error("The MATLAB path is invalid. Ensure the \"MATLAB_HOME\" evironmental variable to the MATLAB root directory.")
        end
    end
    return matlab_cmd
end

matlab_homepath = find_matlab_homepath()

if !isnothing(matlab_homepath)
    matlab_libpath = find_matlab_libpath(matlab_homepath)
    matlab_cmd = find_matlab_cmd(matlab_homepath)
    libmx_size = filesize(Libdl.dlpath(joinpath(matlab_libpath, "libmx")))
    open(depsfile, "w") do io
        println(io,
            """
            # This file is automatically generated, do not edit.

            function check_deps()
                if libmx_size != filesize(Libdl.dlpath(joinpath(matlab_libpath, "libmx")))
                    error("MATLAB library has changed, re-run Pkg.build(\\\"MATLAB\\\")")
                end
            end
            """
            )
            println(io, "const matlab_libpath = \"$(escape_string(matlab_libpath))\"")
            println(io, "const matlab_cmd = \"$(escape_string(matlab_cmd))\"")
            println(io, "const libmx_size = $libmx_size")
    end
elseif get(ENV, "JULIA_REGISTRYCI_AUTOMERGE", nothing) == "true"
    # We need to be able to install and load this package without error for
    # Julia's registry AutoMerge to work, so we just use dummy values.
    matlab_libpath = ""
    matlab_cmd = ""
    libmx_size = 0

    open(depsfile, "w") do io
        println(io,
            """
            # This file is automatically generated, do not edit.

            check_deps() = nothing
            """
            )
            println(io, "const matlab_libpath = \"$(escape_string(matlab_libpath))\"")
            println(io, "const matlab_cmd = \"$(escape_string(matlab_cmd))\"")
            println(io, "const libmx_size = $libmx_size")
    end
else
    error("MATLAB cannot be found. Set the \"MATLAB_HOME\" environment variable to the MATLAB root directory and re-run Pkg.build(\"MATLAB\").")
end
