defmodule Hyperledger.ErrorView do
  use Hyperledger.Web, :view

  def render("404.uber", _assigns) do
    %{
      uber: %{
        version: "1.0",
        error: %{
          data: [
            %{
              name: "not-found",
              value: "Page not found - 404"
            }
          ]
        }
      }
    }
  end

  def render("500.uber", _assigns) do
    %{
      uber: %{
        version: "1.0",
        error: %{
          data: [
            %{
              name: "server-error",
              value: "Server internal error - 500"
            }
          ]
        }
      }
    }
  end

  # Render all other templates as 500
  def render(_, assigns) do
    render "500.uber", assigns
  end
end
