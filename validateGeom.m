function warn = validateGeom(model)
% VALIDATEGEOM  "Manually" check a comsol model for tags with warnings
% within the geometry.
%   WARN = VALIDATEGEOM(MODEL) Iterates through the tags within the
%   geometry of model MODEL and sets WARN to true if a tag is found with
%   warnings.

    % Make sure geometry is build before check
    mphrun(model,'geom');

    % Get all tags within the workplane.
    geomTags = mphtags(model.component('comp1').geom('geom1'));

    % Iterate through all workplane nodes.
    for i = 1:length(geomTags)
        geomTag = geomTags{i};

        % Check if tag is reporting problem.
        tagProblems = model.component('comp1').geom('geom1').feature(geomTag).problems;

        if ~isempty(tagProblems) 
            % Return true if problems exist.
            warn = true;
            return;
        end
    end

    % No problems found!
    warn = false;
end