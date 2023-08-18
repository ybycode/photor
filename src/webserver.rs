use axum::response::Html;
use axum::{routing::get, Router};
use diesel::sqlite::SqliteConnection;
use std::net::SocketAddr;

#[tokio::main]
pub async fn serve(_conn: &mut SqliteConnection) {
    let routes = Router::new().route(
        "/",
        get(|| async { Html("Hello, <strong>World!</strong>") }),
    );

    let addr = SocketAddr::from(([0, 0, 0, 0], 8080));
    println!("Starting the web server on http://{addr}\n");
    axum::Server::bind(&addr)
        .serve(routes.into_make_service())
        .await
        .unwrap();
}
