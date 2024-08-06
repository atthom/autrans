using Genie

route("/") do
    serve_static_file("static/index.html")
end


route("/schedule", method=POST) do
    "hello"
end