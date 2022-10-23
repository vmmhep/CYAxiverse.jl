# CYAxiverse.jl

A [Julia](https://julialang.org) package to compute axion/ALP spectra from string theory (using output of [CYTools](https://cytools.liammcallistergroup.com/))

---

## Authors
[Viraf M. Mehta](https://inspirehep.net/authors/1228975)

## Installation
!!! info
    This package runs in a docker container with `CYTools`.  In time, the installation process will be automated.

To build this docker container, follow these instructions (currently only appropriate for UNIX-based systems):
    
- install the appropriate [Docker Desktop](https://docs.docker.com/desktop/) for your system
- in a terminal, create a new directory for `CYTools` and `CYAxiverse` e.g.
```
mkdir ~/cyaxiverse/ && 
mkdir ~/cyaxiverse/CYTools_repo/ && 
mkdir ~/cyaxiverse/CYAxiverse_repo/
```
- clone the `CYTools` repository
```
cd ~/cyaxiverse/CYTools_repo/ &&
git clone https://github.com/LiamMcAllisterGroup/cytools.git
```
- clone[^1] this repository (currently `dev` branch is up-to-date)

[^1]: 
    one can also `git pull` the repository -- this would enable the `CYAxiverse.jl` package to be updated (while under development) with specific directory binding.  Use this command instead:
    ```
    cd ~/cyaxiverse/CYAxiverse_repo/ &&
    git init &&
    git pull https://github.com/vmmhep/CYAxiverse.jl.git dev 
    ```
    and then you can keep this up-to-date as improvements are pushed with 
    ```
    git pull https://github.com/vmmhep/CYAxiverse.jl.git dev
    ```

```
cd ~/cyaxiverse/CYAxiverse_repo && 
git clone -b dev https://github.com/vmmhep/CYAxiverse.jl.git
```
- replace the default `Dockerfile` in your `CYTools` directory with the `Dockerfile` in **this** repository and move `add_CYAxiverse.jl` there too
```
mv ~/cyaxiverse/cytools/Dockerfile ~/cyaxiverse/Dockerfile_CYTools && 
cp ~/cyaxiverse/CYAxiverse_repo/CYAxiverse.jl/Dockerfile ~/cyaxiverse/cytools/ && 
cp ~/cyaxiverse/CYAxiverse_repo/CYAxiverse.jl/add_CYAxiverse.jl ~/cyaxiverse/cytools/
```
- run the following command from your `CYTools` directory _e.g._ `cyaxiverse/cytools/` :
```
docker build --no-cache --force-rm -t CYAxiverse:uid-$UID --build-arg USERNAME=cytools \
--build-arg USERID=$UID --build-arg ARCH=amd64 \
--build-arg AARCH=x86_64 --build-arg VIRTUAL_ENV=/home/cytools/cytools-venv/ \
--build-arg ALLOW_ROOT_ARG=" " --build-arg PORT_ARG=$(($UID+2875)) .
```
!!! note 
    This takes ~550 seconds on a
    ``` 
    MacBook Pro (13-inch, 2017, Two Thunderbolt 3 ports)
    Processor   2,3 GHz Dual-Core Intel Core i5
    Memory      16 GB 2133 MHz LPDDR3
    ```
- create a `dir` for your data _e.g._
```
mkdir ~/cyaxiverse/CYAxiverse_database
```
- you can now run your docker image with[^2]

[^2]: 
    in order to keep `CYAxiverse.jl` up-to-date (while under development), bind the local `CYAxiverse` version with the `CYAxiverse.jl` directory in the Docker container, _e.g._ with the
    ```
    --mount type=bind,source=~/cyaxiverse/CYAxiverse_repo/CYAxiverse.jl,target=/opt/CYAxiverse,readonly`
    ```
     option included.  Enabling this ensures the `CYAxiverse.jl` version compiled in the Docker container matches the one most recently `fetch`ed from the repository.

```
docker container run -it --mount type=bind,source=~/cyaxiverse/CYAxiverse_data,\
target=/database,rw -p 8994:8996 CYAxiverse
```
and then opening a browser and going to [`http://localhost:8994`](http://localhost:8994).

Good luck!

!!! warning
    This package is currently _not_ registered with the `julia` package manager and is still under development.  **Use at your own risk!**

## Acknowledgements
This project was born after publication of [Superradiance in String Theory](https://iopscience.iop.org/article/10.1088/1475-7516/2021/07/033) and I am grateful to my collaborators for their input while this code was evolving.