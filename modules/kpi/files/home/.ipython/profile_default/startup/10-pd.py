def tsv_to_csv(fname, save_to=None):
    import pandas as pd
    df = pd.read_csv(fname, delimiter='\t')
    assert len(df.columns) > 1
    if save_to is None:
        save_to = fname
    df.to_csv(save_to)
    print(f'Converted from tsv: {fname}. Saved to: {save_to}')
