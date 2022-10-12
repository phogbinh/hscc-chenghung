function relay_DUEs = get_relay_DUEs(rue_mli, DUEs, combination)
  relay_DUEs = DUE.empty(1, 0);
  for due_mli = 1:numel(combination)
    if combination(due_mli) == rue_mli
      relay_DUEs(end + 1) = DUEs(due_mli);
    end
  end
end
