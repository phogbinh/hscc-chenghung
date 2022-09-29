function plotDiffDUETraffic(NUM_LINE, NUM_POINT)
    sys_capacity(NUM_LINE, NUM_POINT) = struct('x', 0, 'y', 0);
    approxi_sys_energy(NUM_LINE, NUM_POINT) = struct('x', 0, 'y', 0);
    approxi_avg_energy(NUM_LINE, NUM_POINT) = struct('x', 0, 'y', 0);
    % real_sys_energy = zeros([NUM_LINE, NUM_POINT]);
    % real_avg_energy = zeros([NUM_LINE, NUM_POINT]);
    ee(NUM_LINE, NUM_POINT) = struct('x', 0, 'y', 0);
    
    num_points = zeros([1, NUM_LINE]);

    files = dir('./data/Dtraffic/*.json');
    for i = 1:length(files)
        filename = sprintf('./data/Dtraffic/%s', files(i).name);
        str = fileread(filename);
        data = jsondecode(str);
        line = 0;

        switch data.method
            case "equal"
                line = 2;
            case "proposed-1"
                line = 3;
        end
        
        if line == 3
            num_points(1) = num_points(1) + 1;
            sys_capacity(1, num_points(1)).x = data.direct_avg_rate_DUE;
            sys_capacity(1, num_points(1)).y = data.direct_sum_rate;

            approxi_sys_energy(1, num_points(1)).x = data.direct_avg_rate_DUE;
            approxi_sys_energy(1, num_points(1)).y = data.direct_energy;

            approxi_avg_energy(1, num_points(1)).x = data.direct_avg_rate_DUE;
            approxi_avg_energy(1, num_points(1)).y = data.direct_avg_energy;

            ee(1, num_points(1)).x = data.direct_avg_rate_DUE;
            ee(1, num_points(1)).y = data.direct_EE;
        end

        num_points(line) = num_points(line) + 1;
        sys_capacity(line, num_points(line)).x = data.direct_avg_rate_DUE;
        sys_capacity(line, num_points(line)).y = data.sum_rate;

        approxi_sys_energy(line, num_points(line)).x = data.direct_avg_rate_DUE;
        approxi_sys_energy(line, num_points(line)).y = data.sys_energy;

        approxi_avg_energy(line, num_points(line)).x = data.direct_avg_rate_DUE;
        approxi_avg_energy(line, num_points(line)).y = data.avg_energy;

        ee(line, num_points(line)).x = data.direct_avg_rate_DUE;
        ee(line, num_points(line)).y = data.EE;
    end

    color = ['m', 'b', 'c', 'g', 'r','k'];
    marker = ['+', 'o', 'd', 's', '*'];  

    figure();
    for i = 1:NUM_LINE
        hold on;
        x = [sys_capacity(i, 1:num_points(line)).x];
        y = [sys_capacity(i, 1:num_points(line)).y];
        scatter(x, y, 10, color(i), 'LineWidth', 1);
        hold off;
    end
    grid on;
    xlabel('Average capacity of DUEs','FontSize', 14);
    ylabel('System Capacity (Mbps)','FontSize', 14);
    legend('No relaying', 'JMRP', 'JRRP (D = 1)');
    saveas(gcf, './pictures/Dtraffic/sys_capacity.png');

    figure();
    for i = 1:NUM_LINE
        hold on;
        x = [approxi_sys_energy(i, 1:num_points(line)).x];
        y = [approxi_sys_energy(i, 1:num_points(line)).y];
        scatter(x, y, 10, color(i), 'LineWidth', 1);
        hold off;
    end
    grid on;
    xlabel('Average capacity of DUEs','FontSize',14);
    ylabel('System Energy Consumption (\muJ)','FontSize',14);
    legend('No relaying', 'JMRP', 'JRRP (D = 1)');
    saveas(gcf, './pictures/Dtraffic/sys_energy.png');

    figure();
    for i = 1:NUM_LINE
        hold on;
        x = [approxi_avg_energy(i, 1:num_points(line)).x];
        y = [approxi_avg_energy(i, 1:num_points(line)).y];
        scatter(x, y, 10, color(i), 'LineWidth', 1);
        hold off;
    end
    grid on;
    xlabel('Average capacity of DUEs','FontSize',14);
    ylabel('Average RUE Energy Consumption (\muJ)','FontSize',14);
    legend('No relaying', 'JRMP', 'JRRP (D = 1)');
    saveas(gcf, './pictures/Dtraffic/avg_energy.png');

    figure();
    for i = 1:NUM_LINE
        hold on;
        x = [ee(i, 1:num_points(line)).x];
        y = [ee(i, 1:num_points(line)).y];
        scatter(x, y, 10, color(i), 'LineWidth', 1);
        hold off;
    end
    grid on;
    xlabel('Average capacity of DUEs','FontSize',14);
    ylabel('Energy Efficieny','FontSize',14);
    legend('No relaying', 'JMRP', 'JRRP (D = 1)');
    saveas(gcf, './pictures/Dtraffic/energy_efficiency.png');
end