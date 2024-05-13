classdef (Abstract) Model
    % MODEL Specifies the configuration for executing a genetic algorithm
    % based optimization on a COMSOL Multiphysics model.
    %
    % MODEL Properties:
    %   comsolmodel - Path to the COMSOL Multiphysics model file.
    %   params - List of strings detailing the parameter names available in
    %   the model to be used for the optimization.
    %   A - ga A matrix for inequality constraints.
    %   b - ga b vector for inequality constraints.
    %   Aeq - ga Aeq matrix for equality constraints.
    %   beq - ga beq vector for equality constraints
    %   lb - ga Lower bound on X
    %   ub - ga Upper bound on X
    %   fitnessFunc - Function handle for the fitness function to be
    %   executed. Should take a parameter vector and output a numerical
    %   fitness score.
    %
    % MODEL Methods:
    %   init(MODEL) - Optional init logic for the model, passes the loaded
    %   COMSOL model handle.
    %
    %   applyParams(X,MODEL) - Applies the parameter values of vector X to
    %   the comsol model MODEL by matching it to the same index in the
    %   class params vector.
    %
    %   fit(X,MODEL) - Execute the fitness function specified by
    %   fitnessFunc with the parameter value vector X on the COMSOL
    %   Multiphysics model specified by MODEL.
    properties (Abstract)
        comsolmodel;
        params;
        A;
        b;
        Aeq;
        beq;
        lb;
        ub;
        fitnessFunc;
        validateGeometry;
    end

    methods
        function init(~, ~)
            % Optional one-time init functionality
        end

        function applyParams(obj, x, model)
            for i = 1:length(obj.params)
                % Match each parameter value with the specified params
                % "map".
                model.param.set(obj.params(i) , x(i));
            end
        end

        function f = fit(obj,x,model)
            % First apply the params.
            obj.applyParams(x, model);

            if obj.validateGeometry
                hasGeomWarnings = validateGeom(model);

                if hasGeomWarnings
                    f = inf;
                    disp('Current parametrization through geometry warnings in model: ' + x);
                    return;
                end
            end

            % Execute model study
            mphrun(model, 'study');

            % Execute the fitness function.
            f = obj.fitnessFunc(x, model);
        end
    end
end
