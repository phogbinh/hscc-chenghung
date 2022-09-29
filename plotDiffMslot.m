function plotDiffMslot(NUM_METHOD)
    sys_capacity = zeros([1, NUM_METHOD]);
    approxi_sys_energy = zeros([1, NUM_METHOD]);
    approxi_avg_energy = zeros([1, NUM_METHOD]);
    real_sys_energy = zeros([1, NUM_METHOD]);
    real_avg_energy = zeros([1, NUM_METHOD]);
    ee = zeros([1, NUM_METHOD]);
    connected = zeros([1, NUM_METHOD]);
    num_case = zeros([1, NUM_METHOD]);
    
    files = dir('./data/Mslot/*.json');
    for i = 1:length(files)
        filename = sprintf('./data/Mslot/%s', files(i).name);
        str = fileread(filename);
        data = jsondecode(str);
        bar_num = 0;

        switch data.method
            case "equal"
                bar_num = 2;
            case "proposed-1"
                switch data.Mslot
                case 1
                    bar_num = 3;
                case 2
                    bar_num = 4;
                case 7
                    bar_num = 5;
            end
        end


        num_case(1) = num_case(1) + 1; % no relaying
        num_case(bar_num) = num_case(bar_num) + 1;
        
        sys_capacity(1) = sys_capacity(1) + data.direct_sum_rate;
        sys_capacity(bar_num) = sys_capacity(bar_num) + data.sum_rate;

        approxi_sys_energy(1) = approxi_sys_energy(1) + data.direct_energy;
        approxi_sys_energy(bar_num) = approxi_sys_energy(bar_num) + data.sys_energy;

        approxi_avg_energy(1) = approxi_avg_energy(1) + data.direct_avg_energy;
        approxi_avg_energy(bar_num) = approxi_avg_energy(bar_num) + data.avg_energy;

        real_sys_energy(1) = real_sys_energy(1) + data.direct_model_sys_energy;
        real_sys_energy(bar_num) = real_sys_energy(bar_num) + data.model_sys_energy;

        real_avg_energy(1) = real_avg_energy(1) + data.direct_model_avg_energy;
        real_avg_energy(bar_num) = real_avg_energy(bar_num) + data.model_avg_energy;

        ee(1) = ee(1) + data.direct_EE;
        ee(bar_num) = ee(bar_num) + data.EE;

        connected(bar_num) = connected(bar_num) + data.connected/data.NUM_RUE;
    end
    
    sys_capacity = sys_capacity./num_case./1e6;
    approxi_sys_energy = approxi_sys_energy./num_case;
    approxi_avg_energy = approxi_avg_energy./num_case;
    real_sys_energy = real_sys_energy./num_case;
    real_avg_energy = real_avg_energy./num_case;
    ee = ee./num_case;
    connected = connected./num_case;
    disp(connected);

    x = [1:5];
    color = ['m', 'b', 'c', 'g', 'r','k'];
    marker = ['+', 'o', 'd', 's', '*'];  

    figure();
    y = sys_capacity(:);
    bar(x, y);
    set(gca, 'xticklabel', {'No relaying', 'JMRP', ' JRRP    (S_{k} = 1)', ' JRRP    (S_{k} = 2)', ' JRRP    (S_{k} = 7)'});
    fix_xticklabels(gca, 0.2, {'FontSize', 10});
    grid on;
    title('16 UEs, \Delta = 1');
    % for i1=2:numel(connected)
    %     text(x(i1),y(i1),strcat(num2str(connected(i1)*100,'%0.1f'), '%'),...
    %                'HorizontalAlignment','center',...
    %                'VerticalAlignment','bottom')
    % end
    % xlabel('Methods with different paramaters','FontSize',14);
    ylabel('Sum Data Rate (Mbps)','FontSize',14);
    saveas(gcf, './pictures/Mslot/sys_capacity.png');

    figure();
    y = approxi_sys_energy(:);
    bar(x, y);
    set(gca, 'xticklabel', {'No relaying', 'JMRP', ' JRRP    (S_{k} = 1)', ' JRRP    (S_{k} = 2)', ' JRRP    (S_{k} = 7)'});
    fix_xticklabels(gca, 0.2, {'FontSize', 10});
    grid on;
    title('16 UEs, \Delta = 1');
    % xlabel('Methods with different paramaters','FontSize',14);
    ylabel('System Energy Consumption (\muJ)','FontSize',14);
    saveas(gcf, './pictures/Mslot/sys_energy.png');

    figure();
    y = approxi_avg_energy(:);
    bar(x, y);
    set(gca, 'xticklabel', {'No relaying', 'JMRP', ' JRRP    (S_{k} = 1)', ' JRRP    (S_{k} = 2)', ' JRRP    (S_{k} = 7)'});
    fix_xticklabels(gca, 0.2, {'FontSize', 10});
    grid on;
    title('16 UEs, \Delta = 1');
    % xlabel('Methods with different paramaters','FontSize',14);
    ylabel('Average RUE Energy Consumption (\muJ)','FontSize',14);
    saveas(gcf, './pictures/Mslot/avg_energy.png');

    % figure();
    % for i = 1:NUM_LINE
    %     hold on;
    %     y = real_sys_energy(i, :);
    %     plot(x, y, 'Color', color(i), 'Marker', marker(i), 'LineWidth', 1);
    %     hold off;
    % end
    % set(gca, 'XTickMode', 'manual', 'XTick', xtick);
    % grid on;
    % xlabel('Number of mini-slots in an RB','FontSize',14);
    % ylabel('Real System Energy Consumption (\muJ)','FontSize',14);
    % legend('No relaying', 'JMRP', 'JRRP (D = 1)', 'JRRP (D = 2)');
    % saveas(gcf, './pictures/Mslot/real_sys_energy.png');

    % figure();
    % for i = 1:NUM_LINE - 1
    %     hold on;
    %     y = real_sys_energy_improvement(i, :);
    %     plot(x, y, 'Color', color(i), 'Marker', marker(i), 'LineWidth', 1);
    %     hold off;
    % end
    % set(gca, 'XTickMode', 'manual', 'XTick', xtick);
    % grid on;
    % xlabel('Number of mini-slots in an RB','FontSize',14);
    % ylabel('Real System Energy Consumption Improvement(%)','FontSize',14);
    % legend('JMRP', 'JRRP (D = 1)', 'JRRP (D = 2)');
    % saveas(gcf, './pictures/Mslot/real_sys_energy_improve.png');

    % figure();
    % for i = 1:NUM_LINE
    %     hold on;
    %     y = real_avg_energy(i, :);
    %     plot(x, y, 'Color', color(i), 'Marker', marker(i), 'LineWidth', 1);
    %     hold off;
    % end
    % set(gca, 'XTickMode', 'manual', 'XTick', xtick);
    % grid on;
    % xlabel('Number of mini-slots in an RB','FontSize',14);
    % ylabel('Real RUE average Energy Consumption (\muJ)','FontSize',14);
    % legend('No relaying', 'JMRP', 'JRRP (D = 1)', 'JRRP (D = 2)');
    % saveas(gcf, './pictures/Mslot/real_RUE_avg_energy.png');

    % figure();
    % y = ee(:);
    % bar(x, y);
    % set(gca, 'xticklabel', {'No relaying', 'JMRP', ' JRRP    (S_{k} = 1)', ' JRRP    (S_{k} = 2)', ' JRRP    (S_{k} = 7)'});
    % fix_xticklabels(gca, 0.2, {'FontSize', 10});
    % grid on;
    % % xlabel('Methods with different paramaters','FontSize',14);
    % ylabel('Energy Efficieny','FontSize',14);
    % saveas(gcf, './pictures/Mslot/energy_efficiency.png');
end