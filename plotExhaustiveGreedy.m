function plotExhaustiveGreedy(NUM_LINE, NUM_POINT)
% plotExhaustiveGreedy(2, 5)
    sys_capacity = zeros([NUM_LINE, NUM_POINT]);
    approxi_sys_energy = zeros([NUM_LINE, NUM_POINT]);
    approxi_avg_energy = zeros([NUM_LINE, NUM_POINT]);
    time = zeros([NUM_LINE, NUM_POINT]);

    num_case = zeros([NUM_LINE, NUM_POINT]);
    
    files = dir('./data/exhaustiveGreedy/*.json');
    for i = 1:length(files)
        filename = sprintf('./data/exhaustiveGreedy/%s', files(i).name);
        str = fileread(filename);
        data = jsondecode(str);
        line = 0;
        point = 0;

        switch data.method
            case "exhaustive-2"
                line = 1;
            case "proposed-2"
                line = 2;
        end
        switch data.NUM_UE
            case 4
                point = 1;
            case 5
                point = 2;
            case 6
                point = 3;
            case 7
                point = 4;
            case 8
                point = 5;
        end

        num_case(line, point) = num_case(line, point) + 1;
        sys_capacity(line, point) = sys_capacity(line, point) + data.sum_rate;
        approxi_sys_energy(line, point) = approxi_sys_energy(line, point) + data.sys_energy;
        approxi_avg_energy(line, point) = approxi_avg_energy(line, point) + data.avg_energy*data.NUM_RUE;
        time(line, point) = time(line, point) + data.time;
    end
    
    sys_capacity = sys_capacity./num_case./1e6;
    approxi_sys_energy = approxi_sys_energy./num_case;
    approxi_avg_energy = approxi_avg_energy./num_case;
    time = time./num_case;

    x = [4, 5, 6, 7, 8];
    xtick = [4:1:8];
    color = ['m', 'b', 'c', 'g', 'r'];
    marker = ['+', 'o', 'd', 's', '*'];

    for i = 1:NUM_POINT
        fprintf("%d UE: %.2f\n", x(i), time(1, i) / time(2, i))
    end

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
    legend('Exhaustive (\Delta = 2)', 'JRRP (\Delta = 2)', 'Location', 'best');
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
    legend('Exhaustive (\Delta = 2)', 'JRRP (\Delta = 2)', 'Location', 'northwest');
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
    legend('Exhaustive (\Delta = 2)', 'JRRP (\Delta = 2)', 'Location', 'northwest');
    saveas(gcf, './pictures/avg_energy.png');
    
    figure();
    for i = 1:NUM_LINE
        hold on;
        y = time(i, :);
        plot(x, y, 'Color', color(i), 'Marker', marker(i), 'LineWidth', 1);
        hold off;
    end
    set(gca, 'XTickMode', 'manual', 'XTick', xtick);
    grid on;
    xlabel('Number of UEs','FontSize',14);
    ylabel('Execution Time(s)','FontSize',14);
    legend('Exhaustive (\Delta = 2)', 'JRRP (\Delta = 2)', 'Location', 'northwest');
    saveas(gcf, './pictures/time.png');

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