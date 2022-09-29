function plotFigure(NUM_LINE, NUM_POINT)
    sys_capacity = zeros([NUM_LINE, NUM_POINT]);
    approxi_sys_energy = zeros([NUM_LINE, NUM_POINT]);
    approxi_avg_energy = zeros([NUM_LINE, NUM_POINT]);
    real_sys_energy = zeros([NUM_LINE, NUM_POINT]);
    real_avg_energy = zeros([NUM_LINE, NUM_POINT]);
    ee = zeros([NUM_LINE, NUM_POINT]);

    num_case = zeros([NUM_LINE, NUM_POINT]);
    
    files = dir('./data/diffUE/*.json');
    for i = 1:length(files)
        filename = sprintf('./data/diffUE/%s', files(i).name);
        str = fileread(filename);
        data = jsondecode(str);
        line = 0;
        point = 0;

        switch data.method
            case "equal"
                line = 2;
            case "proposed-1"
                line = 3;
            case "proposed-2"
                line = 4;
        end
        switch data.NUM_UE
            case 8
                point = 1;
            case 12
                point = 2;
            case 16
                point = 3;
            case 20
                point = 4;
            case 24
                point = 5;
        end

        num_case(1, point) = num_case(1, point) + 1;
        num_case(line, point) = num_case(line, point) + 1;
        
        sys_capacity(1, point) = sys_capacity(1, point) + data.direct_sum_rate;
        sys_capacity(line, point) = sys_capacity(line, point) + data.sum_rate;

        approxi_sys_energy(1, point) = approxi_sys_energy(1, point) + data.direct_energy;
        approxi_sys_energy(line, point) = approxi_sys_energy(line, point) + data.sys_energy;

        approxi_avg_energy(1, point) = approxi_avg_energy(1, point) + data.direct_avg_energy*data.NUM_RUE;
        approxi_avg_energy(line, point) = approxi_avg_energy(line, point) + data.avg_energy*data.NUM_RUE;

        real_sys_energy(1, point) = real_sys_energy(1, point) + data.direct_model_sys_energy;
        real_sys_energy(line, point) = real_sys_energy(line, point) + data.model_sys_energy;

        real_avg_energy(1, point) = real_avg_energy(1, point) + data.direct_model_avg_energy;
        real_avg_energy(line, point) = real_avg_energy(line, point) + data.model_avg_energy;

        ee(1, point) = ee(1, point) + data.direct_EE;
        ee(line, point) = ee(line, point) + data.EE;
    end
    
    sys_capacity = sys_capacity./num_case./1e6;
    approxi_sys_energy = approxi_sys_energy./num_case;
    approxi_avg_energy = approxi_avg_energy./num_case;
    real_sys_energy = real_sys_energy./num_case;
    real_avg_energy = real_avg_energy./num_case;
    ee = ee./num_case;
    
    real_sys_energy_improvement = zeros([NUM_LINE - 1, NUM_POINT]);
    for i = 2:NUM_LINE
        for p = 1:NUM_POINT
            real_sys_energy_improvement(i - 1, p) = real_sys_energy_improvement(i - 1, p) + ...
                                                (real_sys_energy(1, p) - real_sys_energy(i, p))/real_sys_energy(1, p);
        end
    end

    x = [8, 12, 16, 20, 24];
    xtick = [8:4:24];
    color = ['m', 'b', 'c', 'g', 'r','k'];
    marker = ['+', 'o', 'd', 's', '*'];  

    figure();
    for i = 1:NUM_LINE
        hold on;
        y = sys_capacity(i, :);
        plot(x, y, 'Color', color(i), 'Marker', marker(i), 'LineWidth', 1);
        hold off;
    end
    set(gca, 'XTickMode', 'manual', 'XTick', xtick);
    grid on;
    xlabel('Number of UEs','FontSize',14);
    ylabel('Sum Data Rate (Mbps)','FontSize',14);
    legend('No relaying', 'JMRP', 'JRRP (\Delta = 1)', 'JRRP (\Delta = 2)', 'Location', 'best');
    saveas(gcf, './pictures/sys_capacity.png');

    figure();
    for i = 1:NUM_LINE
        hold on;
        y = approxi_sys_energy(i, :);
        plot(x, y, 'Color', color(i), 'Marker', marker(i), 'LineWidth', 1);
        hold off;
    end
    set(gca, 'XTickMode', 'manual', 'XTick', xtick);
    grid on;
    xlabel('Number of UEs','FontSize',14);
    ylabel('System Energy Consumption (\muJ)','FontSize',14);
    legend('No relaying', 'JMRP', 'JRRP (\Delta = 1)', 'JRRP (\Delta = 2)', 'Location', 'best');
    saveas(gcf, './pictures/sys_energy.png');

    figure();
    for i = 1:NUM_LINE
        hold on;
        y = approxi_avg_energy(i, :);
        plot(x, y, 'Color', color(i), 'Marker', marker(i), 'LineWidth', 1);
        hold off;
    end
    set(gca, 'XTickMode', 'manual', 'XTick', xtick);
    grid on;
    xlabel('Number of UEs','FontSize',14);
    ylabel('Sum Energy Consumption of RUEs(\muJ)','FontSize',14);
    legend('No relaying', 'JRMP', 'JRRP (\Delta = 1)', 'JRRP (\Delta = 2)', 'Location', 'northwest');
    saveas(gcf, './pictures/avg_energy.png');

%     figure();
%     for i = 1:NUM_LINE
%         hold on;
%         y = real_sys_energy(i, :);
%         plot(x, y, 'Color', color(i), 'Marker', marker(i), 'LineWidth', 1);
%         hold off;
%     end
%     set(gca, 'XTickMode', 'manual', 'XTick', xtick);
%     grid on;
%     xlabel('Number of UEs','FontSize',14);
%     ylabel('Real System Energy Consumption (\muJ)','FontSize',14);
%     legend('No relaying', 'JMRP', 'JRRP (\Delta = 1)', 'JRRP (\Delta = 2)');
%     saveas(gcf, './pictures/real_sys_energy.png');
% 
%     figure();
%     for i = 1:NUM_LINE - 1
%         hold on;
%         y = real_sys_energy_improvement(i, :);
%         plot(x, y, 'Color', color(i), 'Marker', marker(i), 'LineWidth', 1);
%         hold off;
%     end
%     set(gca, 'XTickMode', 'manual', 'XTick', xtick);
%     grid on;
%     xlabel('Number of UEs','FontSize',14);
%     ylabel('Real System Energy Consumption Improvement(%)','FontSize',14);
%     legend('JMRP', 'JRRP (\Delta = 1)', 'JRRP (\Delta = 2)');
%     saveas(gcf, './pictures/real_sys_energy_improve.png');
% 
%     figure();
%     for i = 1:NUM_LINE
%         hold on;
%         y = real_avg_energy(i, :);
%         plot(x, y, 'Color', color(i), 'Marker', marker(i), 'LineWidth', 1);
%         hold off;
%     end
%     set(gca, 'XTickMode', 'manual', 'XTick', xtick);
%     grid on;
%     xlabel('Number of UEs','FontSize',14);
%     ylabel('Real RUE average Energy Consumption (\muJ)','FontSize',14);
%     legend('No relaying', 'JMRP', 'JRRP (\Delta = 1)', 'JRRP (\Delta = 2)');
%     saveas(gcf, './pictures/real_RUE_avg_energy.png');
% 
%     figure();
%     for i = 1:NUM_LINE
%         hold on;
%         y = ee(i, :);
%         plot(x, y, 'Color', color(i), 'Marker', marker(i), 'LineWidth', 1);
%         hold off;
%     end
%     set(gca, 'XTickMode', 'manual', 'XTick', xtick);
%     grid on;
%     xlabel('Number of UEs','FontSize',14);
%     ylabel('Energy Efficieny','FontSize',14);
%     legend('No relaying', 'JMRP', 'JRRP (\Delta = 1)', 'JRRP (\Delta = 2)');
%     saveas(gcf, './pictures/energy_efficiency.png');
end