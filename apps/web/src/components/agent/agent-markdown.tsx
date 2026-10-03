import ReactMarkdown, { type Components } from 'react-markdown'
import remarkGfm from 'remark-gfm'

const components: Components = {
  p: ({ children }) => <p className="text-[14px] leading-relaxed">{children}</p>,
  a: ({ children, href }) => (
    <a href={href} target="_blank" rel="noreferrer" className="text-brand underline underline-offset-2 hover:text-brand-strong">
      {children}
    </a>
  ),
  ul: ({ children }) => <ul className="list-disc space-y-1 pl-5 text-[14px] leading-relaxed">{children}</ul>,
  ol: ({ children }) => <ol className="list-decimal space-y-1 pl-5 text-[14px] leading-relaxed">{children}</ol>,
  li: ({ children }) => <li>{children}</li>,
  h1: ({ children }) => <h1 className="text-[16px] font-semibold">{children}</h1>,
  h2: ({ children }) => <h2 className="text-[15px] font-semibold">{children}</h2>,
  h3: ({ children }) => <h3 className="text-[14px] font-semibold">{children}</h3>,
  strong: ({ children }) => <strong className="font-semibold">{children}</strong>,
  blockquote: ({ children }) => <blockquote className="border-l-2 border-border pl-3 text-muted-foreground">{children}</blockquote>,
  hr: () => <hr className="border-border" />,
  table: ({ children }) => (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse text-[13px]">{children}</table>
    </div>
  ),
  th: ({ children }) => <th className="border-b border-border px-2 py-1 text-left font-semibold">{children}</th>,
  td: ({ children }) => <td className="border-b border-border px-2 py-1 align-top">{children}</td>,
  code: ({ className, children }) => {
    // Fenced blocks get a `language-*` class from remark; inline code doesn't.
    const inline = !className
    if (inline) return <code className="rounded bg-secondary px-1 py-0.5 font-mono text-[12.5px]">{children}</code>
    return (
      <pre className="overflow-x-auto rounded bg-secondary p-2.5 font-mono text-[12.5px]">
        <code>{children}</code>
      </pre>
    )
  },
}

/** Renders an agent answer as formatted markdown (headings, lists, code, tables) instead of a raw text blob. */
export function AgentMarkdown({ children }: { children: string }) {
  return (
    <div className="space-y-2">
      <ReactMarkdown remarkPlugins={[remarkGfm]} components={components}>
        {children}
      </ReactMarkdown>
    </div>
  )
}
