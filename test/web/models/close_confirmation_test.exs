defmodule Hyperledger.ModelTest.CloseConfirmation do
  use Hyperledger.ModelCase
    
  alias Hyperledger.CloseConfirmation
  alias Hyperledger.Node
  
  setup do
    {pk, sk} = key_pair
    Node.create(1, "http://localhost:4000", pk)
    data = %{ closeConfirmation: %{ view_id: 1 } }
    sig = sign(data, sk)
    {:ok, data: Poison.encode!(data), sig: sig, pk: pk}
  end
  
  test "`changeset` validates node existence", %{data: data, sig: sig} do
    params = %{
      view_id: 1,
      data: data,
      node_id: 2,
      signature: sig
    }
    
    cs = CloseConfirmation.changeset(params)
    
    assert cs.valid? == false
  end
  
  test "`changeset` checks for signature authenticity", %{data: data} do
    {_pk, sk} = key_pair
    sig = sign(data, sk)
    
    params = %{
      view_id: 1,
      node_id: 1,
      data: data,
      signature: sig
    }
    
    cs = CloseConfirmation.changeset(params)

    assert cs.valid? == false
  end
  
  test "`changeset` checks for duplicates from nodes", %{data: data, sig: sig} do
    params = %{
      view_id: 1,
      node_id: 1,
      data: data,
      signature: sig
    }
    
    CloseConfirmation.changeset(params)
    |> CloseConfirmation.create
    
    cs = CloseConfirmation.changeset(params)
    assert cs.valid? == false
  end
  
  test "`create` inserts a valid changeset", %{data: data, sig: sig} do
    params = %{
      view_id: 1,
      node_id: 1,
      data: data,
      signature: sig
    }
    
    cs = CloseConfirmation.changeset(params)
    
    assert cs.valid? == true
    assert {:ok, %CloseConfirmation{}} = CloseConfirmation.create(cs)
  end
  
  test "`create` closes view if 2/3rds of nodes confirm", %{data: data, sig: sig, pk: pk} do
    Node.create(2, "http://localhost:4000", pk)
    Node.create(3, "http://localhost:4000", pk)
    
    params = %{
      view_id: 1,
      node_id: 1,
      data: data,
      signature: sig
    }
    
    CloseConfirmation.changeset(params)
    |> CloseConfirmation.create
    
    {:ok, cc} =
      params
      |> Map.merge(%{node_id: 2})
      |> CloseConfirmation.changeset
      |> CloseConfirmation.create
    
    assert Repo.one(assoc(cc, :view)).closed == true
  end
end