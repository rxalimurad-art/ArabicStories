interface Props {
  done: number;
  total: number;
}

const SIZE = 116;
const STROKE = 10;
const R = (SIZE - STROKE) / 2;
const C = 2 * Math.PI * R;

/** Daily progress ring — fills as tasks are ticked, turns gold when complete. */
export function ProgressRing({ done, total }: Props) {
  const fraction = total > 0 ? done / total : 0;
  const complete = total > 0 && done === total;
  const offset = C * (1 - fraction);

  return (
    <div className={`ring ${complete ? 'ring--complete' : ''}`}>
      <svg width={SIZE} height={SIZE} viewBox={`0 0 ${SIZE} ${SIZE}`} role="img"
           aria-label={`${done} of ${total} done today`}>
        <circle className="ring__track" cx={SIZE / 2} cy={SIZE / 2} r={R} strokeWidth={STROKE} />
        <circle
          className="ring__value"
          cx={SIZE / 2}
          cy={SIZE / 2}
          r={R}
          strokeWidth={STROKE}
          strokeDasharray={C}
          strokeDashoffset={offset}
          transform={`rotate(-90 ${SIZE / 2} ${SIZE / 2})`}
        />
      </svg>
      <div className="ring__label" aria-hidden="true">
        <span className="ring__count">{done}</span>
        <span className="ring__total">/ {total}</span>
      </div>
      {complete && <p className="ring__done">all done — well done</p>}
    </div>
  );
}
