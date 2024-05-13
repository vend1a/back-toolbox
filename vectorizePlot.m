function vectorizePlot(name) 
    % Change to appropiate units.
    set(gca, 'Units', 'centimeters');
    set(gcf,'PaperUnits', 'centimeter');

    % Get the current size in centimeters.
    ap = get(gca,'Position');

    width = ap(3);
    height = ap(4);

    % Update the print size.
    set(gcf,'PaperPosition', [0,0,width,height])
    set(gcf,'PaperSize', [width,height]);

    print(gcf, name + ".pdf", '-dpdf', '-vector')
end