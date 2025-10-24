function buildyourownagentv2(varargin)

    % Define tools as a cell array of structs
    tools{1} = openaiapi.Tool("list_sr_files", "Returns a list of service request files.", @listSrFiles, "function files = list_sr_files(folder)");
    tools{2} = openaiapi.Tool("read_file", "Reads the content of a specified file in the directory.", @readFile, "function contents = read_file(file_name, folder)");
    tools{3} = openaiapi.Tool("create_file", "Creates a new file of the given name.", @createFile, "function created = create_file(file_name)");
    tools{4} = openaiapi.Tool("write_results", "writes a string to a file", @writeResults, "function written = write_results(file_name, message)");
    tools{5} = openaiapi.Tool("terminate", "Terminates the conversation. No further actions or interactions are possible after this. Prints the provided message for the user.", @terminate, "function message = terminate(message)");


    %Define system instructions (Agent Rules)
    prompt = ['You are an AI agent that can perform tasks by using available tools.', ...
         'create a new, blank file named out.txt', ...
         'retreive the list of service request files from the folder srs.  read each file.  If the file is not in english, translate it to english.', ...
         'for each file, suggest a list of 2-3 tags to categorize the request, an assessment of where it is in the workflow,', ...
         'and an issue type.  Then append the list of tags to out.txt in the form of <srfilebane> : <deploment step> : <issue type> : <tag1>, <tag2>...', ...
         'where deployment step represents the step in the deployment process the customer experienced the issue. ', ...
         'the valid deployment steps are in the file deploymentsteps.txt in the agentdata folder ', ...
         'Valid issue types are: request, howto, inquiry, issue. ', ...
         'The valid tags are in tags.txt in the agentdata folder. ', ...
         'When you are done, terminate the conversation by using the "terminate" tool and I will provide the results to the user.'];

    if(~isempty(varargin))
        prompt = varargin{1};
    end

    a = openaiapi.Agent(prompt, "process srs", tools, "Iterations", 10);
    results = a.runAgent();

    if(length(varargin) > 1)
        varargin{2}.Value = cellfun(@(x)(string(x.role) + " : " + string(x.content)), results);
    end

    % List files in the specified directory
    function fileList = listSrFiles(args)
        fileList = dir(args.folder);
        % Error checking for the dir command
        if isempty(fileList)
            fileList = "No files found in the specified directory";
        elseif ~isfolder(args.folder)
            fileList = "The specified folder does not exist";
        end
        fileList = string({fileList(~[fileList.isdir]).name}).join();
    end

    % Create a new empty file
    function result = createFile(args)
        fileID = fopen(args.file_name, 'w');
        fclose(fileID);
        result = "created " + args.file_name;
    end

    % Read a file contents
    function content = readFile(args)
        if ~isfield(args, "folder")
            args.folder = '.';
        end

        fullPath = fullfile(args.folder, args.file_name);

        try
            fileID = fopen(fullPath, 'r');
            content = string(fscanf(fileID, '%c'));
            fclose(fileID);
        catch e
            if contains(e.message, 'No such file or directory')
                content = ['Error: ', args.file_name, ' not found.'];
            else
                content = ['Error: ', e.message];
            end
        end
    end

% Write results to a file
    function result = writeResults(args)
        fileID = fopen(args.file_name, 'a');
        fprintf(fileID, '%s\n', args.message);
        fclose(fileID);
        result = args.file_name;
    end

    % Terminate the agent loop
    function terminateMsg = terminate(args)
        terminateMsg = ['Termination message: ', args.message];
        disp(terminateMsg);
    end
end