defmodule Hyperledger.ModelTest.Account do
  use Hyperledger.ModelCase
  
  alias Hyperledger.Account
  
  setup do
    {:ok, asset} = create_asset
    {pk, _sk} = key_pair
    {:ok, asset: asset, pk: pk}
  end
  
  test "`changeset` validates encoding of key", %{asset: asset} do
    cs = Account.changeset(%Account{}, %{asset_hash: asset.hash, public_key: "123"})

    assert cs.valid? == false
  end

  test "`changeset` validates presence of asset", %{pk: pk} do
    cs = Account.changeset(%Account{}, %{asset_hash: "123", public_key: pk})

    assert cs.valid? == false
  end

  test "`create` inserts a valid record with balance of 0", %{asset: asset, pk: pk} do
    Account.changeset(%Account{}, %{asset_hash: asset.hash, public_key: pk})
    |> Account.create

    assert Repo.get(Account, pk).balance == 0
  end
end