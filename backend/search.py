from duckduckgo_search import DDGS

from config import SEARCH_MAX_RESULTS


async def web_search(query: str, max_results: int = SEARCH_MAX_RESULTS) -> list[dict]:
    """Search the web using DuckDuckGo and return results."""
    with DDGS() as ddgs:
        results = list(ddgs.text(query, max_results=max_results))
    return [
        {"title": r.get("title", ""), "url": r.get("href", ""), "snippet": r.get("body", "")}
        for r in results
    ]


def format_search_context(results: list[dict]) -> str:
    """Format search results into a context string for the LLM."""
    if not results:
        return "No web search results found."

    lines = ["Here are relevant web search results:\n"]
    for i, r in enumerate(results, 1):
        lines.append(f"{i}. **{r['title']}**")
        lines.append(f"   URL: {r['url']}")
        lines.append(f"   {r['snippet']}\n")

    lines.append(
        "Use the above search results to inform your response. "
        "Cite sources when relevant."
    )
    return "\n".join(lines)
