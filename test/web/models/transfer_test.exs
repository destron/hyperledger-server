defmodule Hyperledger.ModelTest.Transfer do
  use Hyperledger.ModelCase
    
  alias Hyperledger.Account
  alias Hyperledger.Transfer
  alias Hyperledger.Issue
  
  setup do
    {:ok, asset} = create_asset
    {d_pk, _sk} = key_pair
    dest_key = Base.encode16(d_pk)
    
    destination =
      %Account{}
      |> Account.changeset(%{public_key: dest_key, asset_hash: asset.hash})
      |> Account.create
    
    %Issue{}
    |> Issue.changeset(%{uuid: Ecto.UUID.generate, asset_hash: asset.hash, amount: 100}, asset.public_key)
    |> Issue.create
    
    params =
      %{
        uuid: Ecto.UUID.generate,
        source_public_key: asset.primary_account_public_key,
        destination_public_key: destination.public_key,
        amount: 100
      }
    {:ok, params: params, auth_key: asset.primary_account_public_key}
  end

  test "`changeset` validates that the amount is greater than zero", %{params: params, auth_key: source_key} do
    cs = Transfer.changeset(%Transfer{}, Map.merge(params, %{amount: 0}), source_key)
    
    assert cs.valid? == false
  end
  
  test "`changeset` validates that the source account exists", %{params: params, auth_key: source_key} do
    cs = Transfer.changeset(%Transfer{}, Map.merge(params, %{source_public_key: "AA"}), source_key)
    
    assert cs.valid? == false
  end
  
  test "`changeset` validates that the destination account exists", %{params: params, auth_key: source_key} do
    cs = Transfer.changeset(%Transfer{}, Map.merge(params, %{destination_public_key: "AA"}), source_key)
    
    assert cs.valid? == false
  end
  
  test "`changeset` validates that the accounts' asset is the same", %{params: params, auth_key: source_key} do
    {:ok, alt_asset} = create_asset("456")
    params = Map.merge(params, %{source_public_key: alt_asset.primary_account_public_key})
    cs = Transfer.changeset(%Transfer{}, params, source_key)
    
    assert cs.valid? == false
  end
  
  test "`changeset` validates the authorisation key matches", %{params: params} do
    cs = Transfer.changeset(%Transfer{}, params, "0000")
    
    assert cs.valid? == false
  end
    
  test "`create` inserts a changeset into the db", %{params: params, auth_key: source_key} do
    Transfer.changeset(%Transfer{}, params, source_key)
    |> Transfer.create
    
    assert Repo.get(Transfer, params.uuid) != nil
  end

  test "`create` modifies the balance of the source and dest wallet", %{params: params, auth_key: source_key} do
    Transfer.changeset(%Transfer{}, params, source_key)
    |> Transfer.create

    s = Repo.get(Account, params.source_public_key)
    assert s.balance == 0

    d = Repo.get(Account, params.destination_public_key)
    assert d.balance == 100
  end
end