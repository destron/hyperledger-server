defmodule Hyperledger.ModelTest.Issue do
  use Hyperledger.ModelCase

  alias Hyperledger.Issue
  alias Hyperledger.Asset
  
  setup do
    {:ok, asset} = create_asset
    auth_key = asset.public_key
    params =
      %{
        uuid: Ecto.UUID.generate,
        asset_hash: asset.hash,
        amount: 100
      }
    {:ok, params: params, auth_key: auth_key}
  end
  
  test "`changeset` validates that the asset exists", %{params: params, auth_key: auth_key} do
    bad_params = Map.merge(params, %{asset_hash: "123"})
    cs = Issue.changeset(%Issue{}, bad_params, auth_key)
    assert cs.valid? == false
  end
  
  test "`changeset` validates that the amount is greater than zero", %{params: params, auth_key: auth_key} do
    bad_params = Map.merge(params, %{amount: 0})
    cs = Issue.changeset(%Issue{}, bad_params, auth_key)
    assert cs.valid? == false
  end
  
  test "`changeset` validates the authorisation key", %{params: params} do
    cs = Issue.changeset(%Issue{}, params, "0000")
    assert cs.valid? == false
  end
  
  test "`changeset` can skip db checks", %{auth_key: auth_key} do
    asset_hash = :crypto.rand_bytes(32) |> Base.encode16
    params = %{
      uuid: Ecto.UUID.generate,
      asset_hash: asset_hash,
      amount: 100
    }
    
    cs = Issue.changeset(%Issue{}, params, auth_key, skip_db: true)
    assert cs.valid? == true
  end
  
  test "`create` inserts a valid changeset into the db", %{params: params, auth_key: auth_key} do
    cs = Issue.changeset(%Issue{}, params, auth_key)
    
    assert {:ok, %Issue{}} = Issue.create(cs)
    assert Repo.get(Issue, params[:uuid]) != nil
  end

  test "`create` also modifies the balance of the primary wallet", %{params: params, auth_key: auth_key} do
    Issue.changeset(%Issue{}, params, auth_key)
    |> Issue.create

    l = Repo.get(Asset, params[:asset_hash])
    a = Repo.one(assoc(l, :primary_account))
    assert a.balance == 100
  end
  
  test "`create` rolls back when changeset is invalid", %{params: params, auth_key: auth_key} do
    params = Map.merge(params, %{asset_hash: "123"})
    cs = Issue.changeset(%Issue{}, params, auth_key)
    
    assert {:error, _} = Issue.create(cs)
  end
end