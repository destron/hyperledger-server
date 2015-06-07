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

  test "`changeset` can skip checking the db", %{pk: pk} do
    params = %{asset_hash: "0000", public_key: pk}
    cs = Account.changeset(%Account{}, params, skip_db: true)

    assert cs.valid? == true
  end

  test "`create` inserts a valid record with balance of 0", %{asset: asset, pk: pk} do
    cs = Account.changeset(%Account{}, %{asset_hash: asset.hash, public_key: pk})
    
    assert {:ok, %Account{}} = Account.create(cs)
    assert Repo.get(Account, pk).balance == 0
  end
  
  test "`create` with a bad changeset returns :error", %{asset: asset} do
    cs = Account.changeset(%Account{}, %{asset_hash: asset.hash, public_key: "123"})
    
    assert {:error, _} = Account.create(cs)
  end
end