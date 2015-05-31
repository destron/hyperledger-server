defmodule Hyperledger.PageView do
  use Hyperledger.Web, :view
    
  def render("index.uber", %{conn: conn}) do
    %{
      uber: %{
        version: "1.0",
        data: [
          %{
            rel: ["self"],
            name: "hyperledger",
            url: page_url(conn, :index)
          },
          %{
            id: "poolConfig",
            url: pool_url(conn, :index)
          },
          %{
            id: "log",
            rel: ["collection"],
            url: log_entry_url(conn, :index)
          },
          %{
            id: "assets",
            rel: ["collection"],
            url: asset_url(conn, :index),
            data: [
              %{
                name: "create",
                url: asset_url(conn, :create),
                accepting: "application/json",
                action: "append"
              }
            ]
          },
          %{
            id: "accounts",
            rel: ["collection"],
            url: account_url(conn, :index),
            data: [
              %{
                name: "create",
                url: account_url(conn, :create),
                accepting: "application/json",
                action: "append"
              }
            ]
          },
          %{
            id: "transfers",
            rel: ["collection"],
            url: transfer_url(conn, :index),
            data: [
              %{
                name: "create",
                url: transfer_url(conn, :create),
                accepting: "application/json",
                action: "append"
              }
            ]
          }  
        ]
      }
    }
  end
end
