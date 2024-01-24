#!/bin/bash

# Install essential R packages
R -e "install.packages('renv', repos='https://cloud.r-project.org/')"
R -e 'renv::install(c("devtools", 
                        "htmltools", 
                        "htmlwidgets", 
                        "IRkernel", 
                        "tidyverse",
                        "tidymodels",
                        "ggplot2", 
                        "scales", 
                        "BiocManager",
                        "sp"), repos="https://cloud.r-project.org/")'

R -e 'BiocManager::install(c("EBImage", "Cardinal"), dependencies=TRUE)'
R -e 'devtools::install_github("DanGuo1223/CardinalNN", dependencies=TRUE)'