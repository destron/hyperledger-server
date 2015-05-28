defmodule Hyperledger.ModelTest.Issue do
  use Hyperledger.ModelCase

  alias Hyperledger.Issue
  alias Hyperledger.Ledger
  
  setup do
    {:ok, ledger} = create_ledger
    auth_key = ledger.public_key
    params =
      %{
        uuid: Ecto.UUID.generate,
        ledger_hash: ledger.hash,
        amount: 100
      }
    {:ok, params: params, auth_key: auth_key}
  end
  
  test "`changeset` validates that the ledger exists", %{params: params, auth_key: auth_key} do
    bad_params = Map.merge(params, %{ledger_hash: "123"})
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
  
  test "`create` inserts a changeset into the db", %{params: params, auth_key: auth_key} do
    Issue.changeset(%Issue{}, params, auth_key)
    |> Issue.create

    assert Repo.get(Issue, params[:uuid]) != nil
  end

  test "`create` also modifies the balance of the primary wallet", %{params: params, auth_key: auth_key} do
    Issue.changeset(%Issue{}, params, auth_key)
    |> Issue.create

    l = Repo.get(Ledger, params[:ledger_hash])
    a = Repo.one(assoc(l, :primary_account))
    assert a.balance == 100
  end
end