function buildyourownagent()
% Initialize the agent's environment and settings
    runAgent()

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

    % Main script
    function runAgent()
        % Define tool functions as a containers.Map
        toolFunctions = dictionary();
        toolFunctions('list_sr_files') = @listSrFiles;
        toolFunctions('read_file') = @readFile;
        toolFunctions('write_results') = @writeResults;
        toolFunctions('create_file') = @createFile;
        toolFunctions('terminate') = @terminate;

        % Define tools as a cell array of structs
        tools(1) = openaiapi.Tool("list_sr_files", "Returns a list of service request files.", "object", struct('folder', struct('type', 'string')), "folder");
        tools(2) = openaiapi.Tool("read_file", "Reads the content of a specified file in the directory.", "object", struct('file_name', struct('type', 'string'), 'folder', struct('type', 'string')), "file_name");
        tools(3) = openaiapi.Tool("create_file", "Creates a new file of the given name.", "object", struct('file_name', struct('type', 'string')), "file_name");
        tools(4) = openaiapi.Tool("write_results", "writes a string to a file", "object", {struct('file_name', struct('type', 'string'), 'message', struct('type', 'string'))}, "file_name, message");
        tools(5) = openaiapi.Tool("terminate", "Terminates the conversation. No further actions or interactions are possible after this. Prints the provided message for the user.", "object", struct('message', struct('type', 'string')), "message");


        %Define system instructions (Agent Rules)
        agentRules = {struct('role', 'system', ...
             'content', ['You are an AI agent that can perform tasks by using available tools.\n\n', ...
             'create a new, blank file named out.txt\n', ...
             'retreive the list of service request files from the folder srs.  read each file.  If the file is not in english, translate it to english.\n', ...
             'for each file, suggest a list of 2-3 tags to categorize the request, an assessment of where it is in the workflow,\n', ...
             'and an issue type.  Then append the list of tags to out.txt in the form of <srfilebane> : <deploment step> : <issue type> : <tag1>, <tag2>...\n', ...
             'where deployment step represents the step in the deployment process the customer experienced the issue.\n', ...
             'the valid deployment steps are in the file deploymentsteps.txt in the agentdata folder\n', ...
             'Valid issue types are: request, howto, inquiry, issue.\n', ...
             'The valid tags are in tags.txt in the agentdata folder\n\n', ...
             'When you are done, terminate the conversation by using the "terminate" tool and I will provide the results to the user.'])};



        % Initialize agent parameters

        iterations = 0;
        maxIterations = 20;

        userTask = 'process the srs';

        memory = {struct('role', 'user', 'content', userTask)};

        o = openaiapi.OpenAIAPI(memory, tools);

        % The Agent Loop
        finished = false;
        while iterations < maxIterations
            % 1. Construct prompt: Combine agent rules with memory
            disp(jsonencode(memory));
            input = [agentRules, memory];
            %input = agentRules;
            % 2. Generate response from LLM
            disp('Agent thinking...');

            r = o.generateResponse(input);

            % Simulate a response for this example
            disp("Agent response: " + string(r.Status))

            for idx = 1:length(r.FunctionCalls)
                toolFcn = toolFunctions(r.FunctionCalls(idx).Name); 
                if isempty(toolFcn)
                    disp("no function for " + r.FunctionCalls(idx).Name)
                    continue;
                end
                fprintf('Executing: %s with args %s\n', r.FunctionCalls(idx).Name, r.FunctionCalls(idx).Arguments);
                result = toolFcn(jsondecode(r.FunctionCalls(idx).Arguments));
                memory = [memory {struct("role", "assistant", "content", "tool_name " + r.FunctionCalls(idx).Name + " " + string(r.FunctionCalls(idx).Arguments))}]; %#ok
                if ~isempty(result)
                    memory = [memory {struct("role", "user", "content", result)}]; %#ok
                end
                if strfind(r.FunctionCalls(idx).Name, "terminate")
                    finished = true;
                end

            end
            for idx = 1:length(r.Messages)
                disp(r.Messages(idx).Content)
                memory = [memory {struct("role", "user", "content", r.Messages(idx).Content)}]; %#ok
            end
            if finished
                break;
            end
            
            iterations = iterations + 1;
        end
    end

end