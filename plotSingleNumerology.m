function plotSingleNumerology(NUM_LINE)
    sys_capacity = zeros([1, NUM_LINE]);
    direct_sys_capacity = zeros([1, NUM_LINE]);
    JMRP_sys_capacity = zeros([1, NUM_LINE]);
    
    sys_energy = zeros([1, NUM_LINE]);
    direct_sys_energy = zeros([1, NUM_LINE]);
    JMRP_sys_energy = zeros([1, NUM_LINE]);
    
    avg_energy = zeros([1, NUM_LINE]);
    direct_avg_energy = zeros([1, NUM_LINE]);
    JMRP_avg_energy = zeros([1, NUM_LINE]);

    num_case = zeros([1, NUM_LINE]);

    files = dir('./data/diffNu/*.json');
    for i = 1:length(files)
        filename = sprintf('./data/diffNu/%s', files(i).name);
        str = fileread(filename);
        data = jsondecode(str);

        if data.NUM_UE ~= 16
            continue;
        end

        switch data.numerology
            case 0
                line = 1;
            case 1
                line = 2;
            case 2
                line = 3;
            case 10
                line = 4;
            case 210
                line = 5;
        end

        if strcmp(data.method, 'equal')
            JMRP_sys_capacity(line) = JMRP_sys_capacity(line) + data.sum_rate;
            JMRP_sys_energy(line) = JMRP_sys_energy(line) + data.sys_energy;
            JMRP_avg_energy(line) = JMRP_avg_energy(line) + data.avg_energy;
            continue;
        end

        num_case(line) = num_case(line) + 1;
        
        direct_sys_capacity(line) = direct_sys_capacity(line) + data.direct_sum_rate;
        sys_capacity(line) = sys_capacity(line) + data.sum_rate;

        direct_sys_energy(line) = direct_sys_energy(line) + data.direct_energy;
        sys_energy(line) = sys_energy(line) + data.sys_energy;

        direct_avg_energy(line) = direct_avg_energy(line) + data.direct_avg_energy;
        avg_energy(line) = avg_energy(line) + data.avg_energy;
            
    end
    
    sys_capacity = sys_capacity./num_case./1e6;
    direct_sys_capacity = direct_sys_capacity./num_case./1e6;
    JMRP_sys_capacity = JMRP_sys_capacity./num_case./1e6;
    
    sys_energy = sys_energy./num_case;
    direct_sys_energy = direct_sys_energy./num_case;
    JMRP_sys_energy = JMRP_sys_energy./num_case;

    avg_energy = avg_energy./num_case;
    direct_avg_energy = direct_avg_energy./num_case;
    JMRP_avg_energy = JMRP_avg_energy./num_case;

    x = {'I=\{0\}'; 'I=\{1\}'; 'I=\{2\}'; 'I=\{0, 1\}'; 'I=\{0, 1, 2\}'};
    labels= {'No relaying', 'JMRP', 'JRRP'};
    color = ['m', 'b', 'c', 'g', 'r','k'];
    marker = ['+', 'o', 'd', 's', '*', 'x'];  

    figure();
    y = zeros(NUM_LINE, 3, 1);
    for i = 1:NUM_LINE
        y1 = direct_sys_capacity(i);
        y2 = JMRP_sys_capacity(i);
        y3 = sys_capacity(i);
        y(i, 1, 1) = y1;
        y(i, 2, 1) = y2;
        y(i, 3, 1) = y3;
    end
    hB = bar(y);
    grid on;
    ylabel('Sum Data Rate (Mbps)','FontSize',14);
    title('16 UEs, \Delta = 1');
    hAx=gca;            % get a variable for the current axes handle
    hAx.XTickLabel=x; % label the ticks
    set(hB, {'DisplayName'}, {'No relaying', 'JMRP', 'JRRP'}');
    % for i = 2:3
    %     xtips = hB(i).XEndPoints;
    %     ytips = hB(i).YEndPoints;
    %     labels = strcat(compose("%.1f", hB(i).YData*100), '%');
    %     text(xtips, ytips,labels,'HorizontalAlignment','center',...
    % 'VerticalAlignment','bottom')
    % end
    legend();
    saveas(gcf, './pictures/diffNu/sys_capacity_diffNu.png');

    figure();
    y = zeros(NUM_LINE, 2, 1);
    for i = 1:NUM_LINE
        y1 = direct_sys_energy(i);
        y2 = JMRP_sys_energy(i);
        y3 = sys_energy(i);
        y(i, 1, 1) = y1;
        y(i, 2, 1) = y2;
        y(i, 3, 1) = y3;
    end
    hB = bar(y);
    grid on;
    ylabel('System Energy Consumption (\muJ)','FontSize',14);
    title('16 UEs, \Delta = 1');
    hAx=gca;            % get a variable for the current axes handle
    hAx.XTickLabel=x; % label the ticks
    set(hB, {'DisplayName'}, {'No relaying', 'JMRP', 'JRRP'}');
    legend();
    ylim([0 4000]);
    saveas(gcf, './pictures/diffNu/sys_energy_diffNu.png');

    figure();
    y = zeros(NUM_LINE, 2, 1);
    for i = 1:NUM_LINE
        y1 = direct_avg_energy(i);
        y2 = JMRP_avg_energy(i);
        y3 = avg_energy(i);
        y(i, 1, 1) = y1;
        y(i, 2, 1) = y2;
        y(i, 3, 1) = y3;
    end
    hB = bar(y);
    grid on;
    ylabel('Average RUE Energy Consumption (\muJ)','FontSize',14);
    title('16 UEs, \Delta = 1');
    hAx=gca;            % get a variable for the current axes handle
    hAx.XTickLabel=x; % label the ticks
    set(hB, {'DisplayName'}, {'No relaying', 'JMRP', 'JRRP'}');
    legend();
    ylim([0 300]);
    saveas(gcf, './pictures/diffNu/avg_energy_diffNu.png');
end