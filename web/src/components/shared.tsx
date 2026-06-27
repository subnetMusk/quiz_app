// Componenti di presentazione condivisi tra i renderer di domanda.

import type { AnswerResult } from "../quiz/evaluate";
import { Icon, type IconName } from "./Icon";

const RESULT_META: Record<AnswerResult, { title: string; icon: IconName }> = {
  correct: { title: "Corretto", icon: "check" },
  incomplete: { title: "Parziale", icon: "exclam" },
  wrong: { title: "Sbagliato", icon: "xmark" },
};

export function CodeBlock({ code }: { code?: string }) {
  if (!code) return null;
  return <pre className="code">{code}</pre>;
}

/** Box di feedback con barra accent + icona (stile iOS), mostrato dopo la conferma. */
export function Feedback({
  result,
  explanation,
  children,
}: {
  result: AnswerResult;
  explanation?: string;
  children?: React.ReactNode;
}) {
  const meta = RESULT_META[result];
  return (
    <div className={`feedback feedback--${result}`} role="status">
      <div className="feedback__head">
        <Icon name={meta.icon} />
        <span>{meta.title}</span>
      </div>
      {explanation && (
        <p className="feedback__body" style={{ whiteSpace: "pre-wrap" }}>
          {explanation}
        </p>
      )}
      {children}
    </div>
  );
}

/** Pulsante "Conferma" full-width usato dai renderer interattivi. */
export function ConfirmButton({
  disabled,
  onClick,
}: {
  disabled: boolean;
  onClick: () => void;
}) {
  return (
    <div className="btn-row btn-row--stack" style={{ marginTop: "var(--gap)" }}>
      <button
        className="btn btn--primary btn--block"
        disabled={disabled}
        onClick={onClick}
      >
        Conferma
      </button>
    </div>
  );
}
