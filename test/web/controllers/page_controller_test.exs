defmodule Hyperledger.PageControllerTest do
  use Hyperledger.ConnCase
  
  test "GET the root path returns 200 and is an UBER resource" do
    conn = get conn(), "/"
    [content_type] = get_resp_header(conn, "content-type")

    assert conn.status == 200
    assert content_type =~ "application/vnd.uber-amundsen+json"
  end
  
  test "GET a bad page returns an UBER 404" do
    conn = conn()
           |> put_req_header("accept", "application/vnd.uber-amundsen+json")
           |> get "/foo"
     
    [content_type] = get_resp_header(conn, "content-type")
    assert conn.status == 404
    assert content_type =~ "application/vnd.uber-amundsen+json"
  end
end