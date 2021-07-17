## Copyright (C) 2020 The Octave Project Developers
## 
## This program is free software: you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
## 
## This program is distributed in the hope that it will be useful, but
## WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
## 
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see
## <https://www.gnu.org/licenses/>.


classdef JupyterNotebook < handle

  ## -*- texinfo -*- 
  ## @deftypefn  {} {@var{notebook} =} JupyterNotebook ()
  ##
  ## Run and fill Jupyter Notebooks within GNU Octave. 
  
  properties
    notebook = struct()
  endproperties

  properties (Access = "private")
    context = struct("ans", "")
  endproperties

  methods
    function obj = JupyterNotebook (notebookFileName)
      if (nargin != 1)
        print_usage ();
      endif

      if (! (ischar (notebookFileName) && isrow (notebookFileName)))
        error ("JupyterNotebook: notebookFileName must be a string");
      endif

      obj.notebook = jsondecode(fileread(notebookFileName));

      % Validate the notebook's format according to nbformat: 4.0 
      if (! (isfield (obj.notebook, "metadata") && 
             isfield (obj.notebook, "nbformat") &&
             isfield (obj.notebook, "nbformat_minor") && 
             isfield (obj.notebook, "cells")))
        error ("JupyterNotebook: not valid format for Jupyter notebooks");
      endif

      % issue a warning if the format is lower than 4.0
      if (obj.notebook.nbformat < 4)
        warning ("JupyterNotebook: nbformat versions lower than 4.0 are not supported")
      endif

      for i = 1:numel(obj.notebook.cells)
        if ( ! isfield (obj.notebook.cells{i}, "source"))
          error ("JupyterNotebook: cells must contain a \"source\" field");
        endif
        if ( ! isfield (obj.notebook.cells{i}, "cell_type"))
          error ("JupyterNotebook: cells must contain a \"cell_type\" field");
        endif
      endfor
    endfunction

    function generateOctaveScript (obj, scriptFileName)
      if (nargin != 2)
        print_usage ();
      endif

      if (! (ischar (scriptFileName) && isrow (scriptFileName)))
        error ("JupyterNotebook: scriptFileName must be a string");
      endif

      fhandle = fopen(scriptFileName, "w");

      for i = 1:numel(obj.notebook.cells)
        if (strcmp(obj.notebook.cells{i}.cell_type, "markdown"))
          fputs (fhandle, "\n#{\n");
        endif

        for k = 1:numel(obj.notebook.cells{i}.source)
          fputs (fhandle, obj.notebook.cells{i}.source{k});
        endfor

        if (strcmp(obj.notebook.cells{i}.cell_type, "markdown"))
          fputs (fhandle, "\n#}\n");
        endif
        fputs (fhandle, "\n");
      endfor
      fclose (fhandle);
    endfunction

    function generateNotebook (obj, notebookFileName)
      if (nargin != 2)
        print_usage ();
      endif

      if (! (ischar (notebookFileName) && isrow (notebookFileName)))
        error ("JupyterNotebook: notebookFileName must be a string");
      endif

      fhandle = fopen(notebookFileName, "w");

      fputs (fhandle, jsonencode (obj.notebook, "ConvertInfAndNaN", false,
                                  "PrettyPrint", true));

      fclose (fhandle);
    endfunction

    function run (obj, cell_index)
      if (nargin != 2)
        print_usage ();
      endif

      if (! (isscalar (cell_index) && ! islogical (cell_index) &&
          mod (cell_index, 1) == 0 && cell_index > 0))
        error ("JupyterNotebook: cell_index must be a scalar positive integer");
      endif

      if (cell_index > length (obj.notebook.cells))
        error ("JupyterNotebook: cell_index is out of bound");
      endif

      obj.notebook.cells{cell_index}.outputs = {};

      stream_output = struct ("name", "stdout", "output_type", "stream");
     
      for i = 1 : numel (obj.notebook.cells{cell_index}.source)
        output_line = obj.evalCode (obj.notebook.cells{cell_index}.source{i});
        
        if (isempty (output_line))
          continue;
        endif

        # Split lines into separate elements in the "text" cell
        output_lines = strsplit (output_line, "\n");     
        for k = 1 : numel (output_lines)
          stream_output.text {end + 1} = output_lines{k};
        endfor
      endfor
      
      if (isfield (stream_output, "text"))
        obj.notebook.cells{cell_index}.outputs{end + 1} = stream_output;
      endif 
    endfunction
  endmethods

  methods (Access = "private")
    function retVal = evalCode (__obj__, __code__)
      if (nargin != 2)
        print_usage ();
      endif

      if (! (ischar (__code__) && isrow (__code__)))
        error ("JupyterNotebook: code must be a string");
      endif

      if (isempty (__code__))
        return;
      endif

      __obj__.evalContext ("load");

      retVal = evalc (__code__, "printf (\"error: \"); printf (lasterror.message)");

      # Handle the ans var in the context
      if (length (retVal) > 6 && strcmp (retVal(1:3), "ans"))
        __obj__.context.ans = retVal(7:length (retVal));
      endif

      __obj__.evalContext ("save");

    endfunction

    function evalContext (obj, op)
      if (strcmp (op, "save"))
        # Handle the ans var in the context
        obj.context = struct("ans", obj.context.ans);
        
        forbidden_var_names = {"__code__", "__obj__", "ans"};

        ## Get variable names
        var_names = {evalin("caller", "whos").name};

        ## Store all variables to context
        for i = 1:length (var_names)
          if (! any (strcmp (var_names{i}, forbidden_var_names)))
            obj.context.(var_names{i}) = evalin ("caller", var_names{i});
          endif
        endfor
      elseif (strcmp (op, "load"))
        for [val, key] = obj.context
          assignin ("caller", key, val);
        endfor
      endif
    endfunction
  endmethods

endclassdef
