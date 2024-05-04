function optimize(model, npop, ngen, cache, nw)
% OPTIMIZE  Runs a genetic algorithm optimization procudure on a model. 
%   OPTIMIZE(MODEL, NPOP, NGEN, NW, SLIDESHOW) runs a genetic algorithm
%   optimization powered by the Global Optimization Toolbox ga function.
%   The MODEL is a sublass of the Model class, NPOP controls the population
%   number fed to ga, NGEN controls the generation count fed to ga, NW is
%   the number of workers to be used (NW = 0 disables the use of
%   parallelism) and SLIDESHOW is a flag that when enabled saves a plot for
%   the best performing solution each generation. 
%
%   See also ga, gcp.
arguments
    model Model
    npop (1,1) {mustBeNumeric} = 5;
    ngen (1,1) {mustBeNumeric} = 2;
    cache (1,1) {mustBeNumericOrLogical} = 0;
    nw (1,1) {mustBeNumeric} = 0;
end

% Disable parallelism if number of workers set to zeto. 
isParallel = nw > 0;

if isParallel && cache
    error("Cache is not supported while running on multiple workers!");
end

pool = [];

if isParallel
    % Start new parallel pool.
    pool = gcp('nocreate');
    
    % Quit the active parallel pool if it exists. 
    if ~isempty(pool)
        delete(pool)
    end

    pool = parpool(nw);
end

% Create model constant
% Important for reliable sync between workers, is only copied once then
% each worker has it's own instance.  
% (Behaves as a normal variable without parallelism)
modelConstant = [];
cacheStorage = configureDictionary('string', 'double');

if isParallel
    modelConstant = parallel.pool.Constant(model);
else
    modelConstant = model;
end

tic;

% Configure the genetic algorithm
ga_options = optimoptions('ga','PopulationSize', npop, 'MaxGenerations', ngen, 'UseParallel', isParallel, 'Display', 'iter', 'OutputFcn', @outputFunc);

% Execute the genetic algorithm
nvars = length(model.params);
[x, fitness] = ga(@workerFitness, nvars, model.A, model.b, model.Aeq, model.beq, model.lb, model.ub, [], ga_options);

if isParallel
    % Shutdown the parallel pool 
    delete(pool);
end

workerReload();

pt = toc;
time = pt / 60;

% Present results.
disp("Solution:")
disp(x)
disp("Fitness:")
disp(fitness);
disp("Time:")
disp(time + " min");

% Create the result struct to save
result.x = x;
result.fitness = fitness;
result.npop = npop;
result.ngen = ngen;
result.time = time;

% Save the result
resultSaver(model, result);

    function f = workerFitness(x)
        % Required to access ModelUtil.
        import com.comsol.model.util.*
        
        paramKey = strjoin(x+"",'');

        if cache && isKey(cacheStorage, paramKey)
            f = lookup(cacheStorage, paramKey);            
            disp('Using cached value for key ' + paramKey + ' : ' + f);
            return;
        end

        try
            % Fetch the constant 
            modelV = [];

            if isParallel
                modelV = modelConstant.Value;
            else
                modelV = modelConstant;
            end

            % Check what models are loaded into the server
            loadedModels = ModelUtil.tags;

            if isempty(loadedModels)
                % No model has been loaded, load our model.
                loadFunc = str2func(modelV.comsolmodel);

                comsolModel = loadFunc();
                modelV.init(comsolModel);
            else
                % Our model has already been loaded, fetch a reference to
                % it. 
                modelTag = loadedModels(1);
                comsolModel = ModelUtil.model(modelTag);
            end

            % Execute the fitness function
            f = modelV.fit(x, comsolModel);
        catch error
            f = inf;
            disp(error.message);
        end

        if cache
            disp('Storing value for key ' + paramKey + ' : ' + f);
            cacheStorage = insert(cacheStorage, paramKey, f); 
        end
    end

    function workerReload()
        import com.comsol.model.util.*

        loadedModels = ModelUtil.tags;

        if ~isempty(loadedModels)
            % Remove the currently loaded model to free up LiveLink memory.
            ModelUtil.remove(loadedModels(1));
        end
    end

    function  [state,options,optchanged] = outputFunc(options, state, ~)
        optchanged = false;

        if isParallel
            % Reload the model on each worker.
            % (Main thread is not used for optimization)
            reloadFuture = parfevalOnAll(pool, @workerReload, 0);
            wait(reloadFuture);
        else
            % Reload the model on the main thread.
            workerReload();
        end
    end
end

