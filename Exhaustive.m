function [res_RUE, res_DUEs, res_profit] = Exhaustive(RUE, DUEs)
  res_RUE = RUE;
  res_DUEs = DUEs;
  res_profit = 0;
  for combination = 0:2^(length(DUEs)) - 1
    [cur_RUE, cur_DUEs, cur_profit] = get_profit(RUE, get_relay_DUEs(DUEs, combination), DUEs);
    if cur_profit > res_profit
      res_RUE = cur_RUE;
      res_DUEs = cur_DUEs;
      res_profit = cur_profit;
    end
  end
end

% DUEs is only for res_DUEs to copy
function [res_RUE, res_DUEs, res_profit] = get_profit(RUE, relay_DUEs, DUEs)
  global MAX_LEN
  if length(relay_DUEs) > MAX_LEN
    res_RUE = RUE;
    res_DUEs = DUEs;
    res_profit = -1;
    return
  end
  res_RUE = RUE.copy();
  res_DUEs = DUEs.copy();
  res_profit = -1;
  for mli = 1:length(relay_DUEs)
    [status, alloc_RUE, alloc_DUEs, profit, weight] = bSearch(res_RUE, relay_DUEs(mli));
    if ~strcmp(status, "Solved")
      res_profit = -1;
      return
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

function relay_DUEs = get_relay_DUEs(DUEs, combination)
  relay_DUEs = DUE.empty(1, 0);
  for due_mli = 1:length(DUEs)
    if bitget(combination, due_mli)
      relay_DUEs(end + 1) = DUEs(due_mli);
    end
  end
end
