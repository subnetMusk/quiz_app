// Piccolo set di icone inline (stile SF Symbols), a tinta unica (currentColor).

type IconName =
  | "book"
  | "cards"
  | "link"
  | "scale"
  | "doc"
  | "case"
  | "chevron"
  | "check"
  | "xmark"
  | "exclam"
  | "bulb"
  | "arrow"
  | "trophy"
  | "list"
  | "sparkles";

const PATHS: Record<IconName, React.ReactNode> = {
  book: (
    <path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H19a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H6.5A2.5 2.5 0 0 0 4 21.5V5.5Zm2.5 12.5H18M8 7h8M8 10.5h6" />
  ),
  cards: (
    <path d="M7 8.5 9 4l11 4.2a1 1 0 0 1 .6 1.3l-3.4 9a1 1 0 0 1-1.3.6L8 16M4 9h8a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1Z" />
  ),
  link: <path d="M9 15l6-6M10.5 6.5l1.8-1.8a4 4 0 0 1 5.7 5.7L16 12m-4 5.5-1.8 1.8a4 4 0 0 1-5.7-5.7L6 11.5" />,
  scale: <path d="M12 3v18M5 8l-3 6a3 3 0 0 0 6 0L5 8Zm14 0-3 6a3 3 0 0 0 6 0l-3-6ZM6 6h12" />,
  doc: <path d="M6 3h8l4 4v13a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Zm8 0v4h4M8 12h8M8 16h6" />,
  case: <path d="M4 8h16a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1Zm5 0V6a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M3 13h18" />,
  chevron: <path d="M9 6l6 6-6 6" />,
  check: <path d="M5 13l4 4L19 7" />,
  xmark: <path d="M6 6l12 12M18 6 6 18" />,
  exclam: <path d="M12 8v5m0 3.5v.5M10.3 4.3 2.6 18a1.5 1.5 0 0 0 1.3 2.2h16.2a1.5 1.5 0 0 0 1.3-2.2L13.7 4.3a2 2 0 0 0-3.4 0Z" />,
  bulb: <path d="M9 18h6m-5 3h4M12 3a6 6 0 0 0-4 10.5c.7.6 1 1.2 1 2V16h6v-.5c0-.8.3-1.4 1-2A6 6 0 0 0 12 3Z" />,
  arrow: <path d="M5 12h14m-6-6 6 6-6 6" />,
  trophy: <path d="M7 4h10v4a5 5 0 0 1-10 0V4Zm0 2H4v1a3 3 0 0 0 3 3m10-4h3v1a3 3 0 0 1-3 3m-5 5v3m-3 3h6l-1-3h-4l-1 3Z" />,
  list: <path d="M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01" />,
  sparkles: <path d="M12 3l1.6 4.4L18 9l-4.4 1.6L12 15l-1.6-4.4L6 9l4.4-1.6L12 3Zm6 9 .8 2.2L21 15l-2.2.8L18 18l-.8-2.2L15 15l2.2-.8L18 12Z" />,
};

export function Icon({
  name,
  size = 20,
  className,
}: {
  name: IconName;
  size?: number;
  className?: string;
}) {
  return (
    <svg
      className={`icon${className ? " " + className : ""}`}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {PATHS[name]}
    </svg>
  );
}

export type { IconName };
