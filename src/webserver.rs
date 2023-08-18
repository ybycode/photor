use axum::{routing::get, Router};
use diesel::sqlite::SqliteConnection;

#[tokio::main]
pub async fn serve(conn: &mut SqliteConnection) {
    let app = Router::new().route("/", get(|| async { "Hello, World!" }));

    println!("Starting the web server on http://0.0.0.0:3000");
    axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}
