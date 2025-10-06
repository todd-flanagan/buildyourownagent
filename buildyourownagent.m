function buildyourownagent()
% Initialize the agent's environment and settings
    runAgent()


    function codeBlock = extractMarkdownBlock(response, blockType)
        if nargin < 2
            blockType = "json";
        end

        if ~contains(response, '```')
            codeBlock = response;
            return;
        end

        parts = strsplit(response, '```');
        codeBlock = strtrim(parts{2});

        if startsWith(codeBlock, blockType)
            codeBlock = strtrim(extractAfter(codeBlock, blockType));
        end
    end


    % List files in the specified directory
    function fileList = listSrFiles(args)
        fileList = dir(args.folder);
        fileList = {fileList(~[fileList.isdir]).name};
    end

% Create a new empty file
    function createFile(args)
        fileID = fopen(args.file_name, 'w');
        fclose(fileID);
    end

    % Read a file contents
    function content = readFile(args)
        if ~isfield(args.folder) < 2
            args.folder = '.';
        end

        fullPath = fullfile(args.folder, args.fileName);

        try
            fileID = fopen(fullPath, 'r');
            content = fscanf(fileID, '%c');
            fclose(fileID);
        catch e
            if contains(e.message, 'No such file or directory')
                content = ['Error: ', args.fileName, ' not found.'];
            else
                content = ['Error: ', e.message];
            end
        end
    end

% Write results to a file
    function writeResults(args)
        fileID = fopen(args.fileName, 'a');
        fprintf(fileID, '%s\n', args.results);
        fclose(fileID);
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
        tools(1) = Tool("list_sr_files", "Returns a list of service request files.", "object", struct('folder', struct('type', 'string')), "folder");
        tools(2) = Tool("read_file", "Reads the content of a specified file in the directory.", "object", struct('file_name', struct('type', 'string'), 'folder', struct('type', 'string')), "file_name");
        tools(3) = Tool("create_file", "Creates a new file of the given name.", "object", struct('file_name', struct('type', 'string')), "file_name");
        tools(4) = Tool("write_results", "writes a string to a file", "object", {struct('file_name', struct('type', 'string'), 'message', struct('type', 'string'))}, "file_name, message");
        tools(5) = Tool("terminate", "Terminates the conversation. No further actions or interactions are possible after this. Prints the provided message for the user.", "object", struct('message', struct('type', 'string')), "message");


        %Define system instructions (Agent Rules)
        agentRules = {struct('role', 'system', ...
             'content', ['You are an AI agent that can perform tasks by using available tools.\n\n', ...
             'create a new, blank file named out.txt\n', ...
             'retreive the list of service request files from the folder buildyourownagent/srs.  read each file.  If the file is not in english, translate it to english.\n', ...
             'for each file, suggest a list of 2-3 tags to categorize the request, an assessment of where it is in the workflow,\n', ...
             'and an issue type.  Then append the list of tags to out.txt in the form of <srfilebane> : <deploment step> : <issue type> : <tag1>, <tag2>...\n', ...
             'where deployment step represents the step in the deployment process the customer experienced the issue.\n', ...
             'the valid deployment steps are in the file buildyourownagent/agentdata/deploymentsteps.txt\n', ...
             'Valid issue types are: request, howto, inquiry, issue.\n', ...
             'The valid tags are in tags.txt in the buildyourownagent/agentdata folder\n\n', ...
             'When you are done, terminate the conversation by using the "terminate" tool and I will provide the results to the user.'])};



        % Initialize agent parameters

        iterations = 0;
        maxIterations = 20;

        userTask = 'process the srs';

        memory = {struct('role', 'user', 'content', userTask)};

        o = OpenAIAPI(memory, tools);

        % The Agent Loop
        while iterations < maxIterations
            % 1. Construct prompt: Combine agent rules with memory
            disp(memory);
%            input = [agentRules, memory];
            input = agentRules;
            % 2. Generate response from LLM
            disp('Agent thinking...');

            r = o.generateResponse(input);

            % Simulate a response for this example
            disp("Agent response: " + string(r.status))

            % Simulate tool calls
            % In a real implementation, we would parse the actual response
            toolCall = any(arrayfun(@(a) strfind(a.type, "function_call"), r.output));

            if toolCall

                for idx = 1:length(r.output)
                    % Simulate tool call
                    if strfind(r.output(idx).type, "function_call")
                        toolFcn = toolFunctions(r.output(idx).name); % Example
                        args = r.output(idx).arguments;
                        fprintf('Executing: %s with args %s\n', r.output(idx).name, args);
                        toolFcn(jsondecode(args))
                    end
                end


                % 5. Update memory with response and results
                memory = [memory, {struct('role', 'assistant', 'content', jsonencode(action))}, ...
                    {struct('role', 'user', 'content', jsonencode(result))}];
            else
                % Handle regular message response
                result = 'Simulated message content';
                disp(['Action result: ', result]);
            end
            
            iterations = iterations + 1;
        end
    end

end