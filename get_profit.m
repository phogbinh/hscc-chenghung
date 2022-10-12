% DUEs is only for res_DUEs to copy
function [res_RUE, res_DUEs, res_profit] = get_profit(RUE, relay_DUEs, DUEs)
  res_RUE = RUE.copy();
  res_DUEs = DUEs.copy();
  res_profit = -1;
  for mli = 1:length(relay_DUEs)
    [status, alloc_RUE, alloc_DUEs, profit, weight] = bSearch(res_RUE, relay_DUEs(mli));
    if ~strcmp(status, "Solved")
      res_profit = -1;
      return;
    end
    res_RUE = alloc_RUE;
    for j = 1:length(alloc_DUEs)
      due_mli = alloc_DUEs(j).getId();
      res_DUEs(due_mli) = alloc_DUEs(j);
      res_DUEs(due_mli).setGrpState(true);
      res_DUEs(due_mli).setGrpRUE(res_RUE);
    end
    res_profit = profit;
  end
end
