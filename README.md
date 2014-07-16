Phase_randomisation
===================

Scripts for randomizing the phases of electron microscopy images based on Chen et al. Ultramicroscopy. The source code was provided by Richard Henderson (MRC LMB). 

To compile the program, use the text file compile/compile_brief.script.txt. You can use the library files that I've included or you can specify the path to the MRC software package library for the files in the compile folder (*.a). 

After compiling, you can use the originally provided HRnoise.script file as a template for running the program. This file was also provided by Richard Henderson.

Alternatively, I've written a python wrapper program that will work on a .img/.hed stack to phase scramble particle stacks. You will have to change a few lines, and I'm happy to help - just message me on github after you've forked this repo!