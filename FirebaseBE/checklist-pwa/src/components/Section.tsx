import type { ReactNode } from 'react';

interface Props {
  label: string;
  accentVar: string;
  children: ReactNode;
}

/** A titled group of task rows, with a small colored dot + uppercase label. */
export function Section({ label, accentVar, children }: Props) {
  return (
    <section className="section">
      <h2 className="section__head">
        <span className="section__dot" style={{ background: accentVar }} aria-hidden="true" />
        {label}
      </h2>
      <div className="section__rows">{children}</div>
    </section>
  );
}
