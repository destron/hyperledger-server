defmodule Hyperledger.AssetView do
  use Hyperledger.Web, :view
  
  def render("index.uber", %{conn: conn, assets: assets}) do
    %{
      uber: %{
        version: "1.0",
        data: [
          %{
            rel: ["self"],
            url: asset_url(conn, :index)
          },
          %{
            id: "assets",
            rel: ["collection"],
            data: Enum.map(assets, fn asset ->
              asset_body(asset, ["item"], conn)
            end)
          }
        ]
      }
    }
  end
  
  def render("show.uber", %{conn: conn, asset: asset}) do
    %{
      uber: %{
        version: "1.0",
        data: [
          asset_body(asset, ["self"], conn)
        ]
      }
    }
  end
  
  defp asset_body(asset, rels, conn) do
    %{
      name: "asset",
      rel: rels,
      data: [
        %{
          name: "hash",
          value: asset.hash
        },
        %{
          name: "publicKey",
          value: asset.public_key
        },
        %{
          name: "primaryAccount",
          url: account_url(conn, :show, asset.primary_account_public_key)
        },
        %{
          name: "issues",
          rel: ["collection"],
          url: asset_issue_url(conn, :index, asset.hash)
        }
      ]
    }
  end
end
