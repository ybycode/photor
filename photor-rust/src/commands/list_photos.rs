use crate::database;

pub async fn run() -> anyhow::Result<()> {
    let pool = database::pool().await?;
    let res = database::list_photos(&pool).await?;

    for p in res {
        println!("{}/{}", p.directory, p.filename);
    }

    Ok(())
}
