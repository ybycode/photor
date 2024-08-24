use axum::extract::{
    Path,
    // Query
};
use axum::response::{Html, IntoResponse};
use axum::routing::{get, get_service};
use axum::Router;
// use serde::Deserialize;
use crate::database;
use lazy_static::lazy_static;
use std::net::SocketAddr;
use tera::Context;
use tera::Tera;
use tower_http::services::ServeDir;

lazy_static! {
    pub static ref TEMPLATES: Tera = {
        let mut tera = match Tera::new("html_templates/**/*") {
            Ok(t) => t,
            Err(e) => {
                println!("Parsing error(s): {}", e);
                ::std::process::exit(1);
            }
        };
        tera.autoescape_on(vec![".html", ".sql"]);
        // tera.register_filter("do_nothing", do_nothing_filter);
        tera
    };
}

pub async fn serve() {
    let routes = Router::new()
        .merge(routes_hello())
        .fallback_service(routes_static());

    let addr = SocketAddr::from(([0, 0, 0, 0], 8080));
    println!("Starting the web server on http://{addr}\n");

    axum::Server::bind(&addr)
        .serve(routes.into_make_service())
        .await
        .unwrap();
}

fn routes_hello() -> Router {
    Router::new()
        .route("/", get(handler_index))
        .route("/:name", get(handler_hello2))
}

// #[derive(Debug, Deserialize)]
// struct HelloParams {
//     name: Option<String>,
// }

// // e.g /hello?name=plop
// async fn handler_index(Query(params): Query<HelloParams>) -> impl IntoResponse {
//     println!("->> {:<12} - handler_hello - {params:?}", "HANDLER");
//     let name = params.name.as_deref().unwrap_or("World");
//     Html(format!("hello, <strong>{name}</strong>"))
// }

async fn handler_index() -> impl IntoResponse {
    let mut context = Context::new();

    let pool = database::pool().await.unwrap();
    let res = database::list_directories(&pool).await.unwrap();

    context.insert("directories", &res);
    let html = TEMPLATES
        .render("index.html", &context)
        .unwrap()
        .to_string();

    println!("->> {:<12} - handler_index ", "HANDLER");
    Html(html)
}

// e.g /hello/:plop
async fn handler_hello2(Path(name): Path<String>) -> impl IntoResponse {
    println!("->> {:<12} - handler_hello - {name:?}", "HANDLER");
    Html(format!("hello, <strong>{name}</strong>"))
}

fn routes_static() -> Router {
    Router::new().nest_service("/", get_service(ServeDir::new("./")))
}
