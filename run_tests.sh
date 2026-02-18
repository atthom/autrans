#!/bin/bash

# Activate the Julia environment for the project
julia --project=. -e 'using Pkg; Pkg.activate(".")'

# Ensure all dependencies are installed and up-to-date
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.update()'

# Precompile the project and its dependencies
julia --project=. -e 'using Pkg; Pkg.precompile()'

# Add Chain to the test environment and run the tests
julia --project=. -e '
    using Pkg;
    Pkg.activate(temp=true);
    Pkg.add("Chain");
    Pkg.develop(PackageSpec(path=pwd()));
    Pkg.test("Autrans")
'

# Optional: Add commands for test coverage or additional reporting here
