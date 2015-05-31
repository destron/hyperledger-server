defmodule Hyperledger.AssetModelTest do
  use Hyperledger.ModelCase
  
  alias Hyperledger.Asset
  alias Hyperledger.Account
  
  setup do
    hash = :crypto.hash(:sha256, "123")
    {pk, _sk} = :crypto.generate_key(:ecdh, :secp256k1)
    {pa_pk, _sk} = :crypto.generate_key(:ecdh, :secp256k1)
    
    params =
      %{
        hash: Base.encode16(hash),
        public_key: Base.encode16(pk),
        primary_account_public_key: Base.encode16(pa_pk)
      }
    {:ok, params: params}
  end
  
  test "`changeset` checks encoding of fields", %{params: params} do
    bad_enc_cs =
      Asset.changeset(
        %Asset{},
        %{
          hash: "GJ9D68b3RCw2HgjzEhtH+TjMcaiYTNntB4W8xa8FhA==",
          public_key: "00",
          primary_account_public_key: "foo bar"}
      )
    
    assert Enum.count(bad_enc_cs.errors) == 2
    
    cs = Asset.changeset(%Asset{}, params)
    
    assert cs.valid? == true
  end
  
  test "`create` inserts a changeset into the db", %{params: params} do
    Asset.changeset(%Asset{}, params)
    |> Asset.create
    
    assert Repo.get(Asset, params.hash) != nil
  end
  
  test "`create` also creates an associated primary account", %{params: params} do
    {:ok, asset} = Asset.changeset(%Asset{}, params)
                   |> Asset.create
    
    primary_acc =
      Account
      |> Repo.get(params.primary_account_public_key)
      |> Repo.preload(:asset)
    
    assert primary_acc != nil
    assert primary_acc.asset == asset
  end
  
  test "`create` returns the asset", %{params: params} do
    cs = Asset.changeset(%Asset{}, params)
    assert {:ok, %Asset{}} = Asset.create(cs)
  end
end