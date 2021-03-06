defmodule Plug.StaticTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule MyPlug do
    use Plug.Builder

    plug Plug.Static, at: "/public", from: Path.expand("..", __DIR__), gzip: true
    plug :passthrough

    defp passthrough(conn, _) do
      Plug.Connection.send_resp(conn, 404, "Passthrough")
    end
  end

  defp call(conn) do
    MyPlug.call(conn, [])
  end

  test "serves the file" do
    conn = conn(:get, "/public/fixtures/static.txt") |> call
    assert conn.status == 200
    assert conn.resp_body == "HELLO"
    assert conn.resp_headers["content-type"]  == "text/plain"
    assert conn.resp_headers["cache-control"] == "public, max-age=31536000"
  end

  test "serves the file with a urlencoded filename" do
    conn = conn(:get, "/public/fixtures/static+with%20spaces.txt") |> call
    assert conn.status == 200
    assert conn.resp_body == "SPACES"
    assert conn.resp_headers["content-type"]  == "text/plain"
    assert conn.resp_headers["cache-control"] == "public, max-age=31536000"
  end

  test "passes through on other paths" do
    conn = conn(:get, "/another/fallback.txt") |> call
    assert conn.status == 404
    assert conn.resp_body == "Passthrough"
  end

  test "passes through on non existing files" do
    conn = conn(:get, "/public/fixtures/unknown.txt") |> call
    assert conn.status == 404
    assert conn.resp_body == "Passthrough"
  end

  test "passes through on directories" do
    conn = conn(:get, "/public/fixtures") |> call
    assert conn.status == 404
    assert conn.resp_body == "Passthrough"
  end

  test "returns 400 for unsafe paths" do
    conn = conn(:get, "/public/fixtures/../fixtures/static/file.txt") |> call
    assert conn.status    == 400
    assert conn.resp_body == "Bad request"

    conn = conn(:get, "/public/c:\\foo.txt") |> call
    assert conn.status    == 400
    assert conn.resp_body == "Bad request"
  end

  test "returns 406 for non-get/non-head requests" do
    conn = conn(:post, "/public/fixtures/static.txt") |> call
    assert conn.status == 406
    assert conn.resp_body == "Method not allowed"
  end

  test "serves gzipped file" do
    conn = conn(:get, "/public/fixtures/static.txt", [],
                headers: [{ "accept-encoding", "gzip" }])
           |> call
    assert conn.status == 200
    assert conn.resp_body == "GZIPPED HELLO"
    assert conn.resp_headers["content-encoding"] == "gzip"

    conn = conn(:get, "/public/fixtures/static.txt", [],
                headers: [{ "accept-encoding", "*" }])
           |> call
    assert conn.status == 200
    assert conn.resp_body == "GZIPPED HELLO"
    assert conn.resp_headers["content-encoding"] == "gzip"
  end

  test "only serve gzipped file if available" do
    conn = conn(:get, "/public/fixtures/static+with%20spaces.txt", [],
                headers: [{ "accept-encoding", "gzip" }])
           |> call
    assert conn.status == 200
    assert conn.resp_body == "SPACES"
    assert conn.resp_headers["content-encoding"] != "gzip"
  end
end
