import { useState, useEffect, useRef } from 'react'
import { SARF_FAMILIES } from '../data/sarf-families-detailed'
import { useHaptic } from '../hooks/useHaptic'

const FAMILY_COLORS = {
  I:    { bg: 'bg-blue-50',    border: 'border-blue-200',   pill: 'bg-blue-100 text-blue-700' },
  II:   { bg: 'bg-purple-50',  border: 'border-purple-200', pill: 'bg-purple-100 text-purple-700' },
  III:  { bg: 'bg-emerald-50', border: 'border-emerald-200',pill: 'bg-emerald-100 text-emerald-700' },
  IV:   { bg: 'bg-amber-50',   border: 'border-amber-200',  pill: 'bg-amber-100 text-amber-700' },
  V:    { bg: 'bg-rose-50',    border: 'border-rose-200',   pill: 'bg-rose-100 text-rose-700' },
  VI:   { bg: 'bg-teal-50',    border: 'border-teal-200',   pill: 'bg-teal-100 text-teal-700' },
  VII:  { bg: 'bg-indigo-50',  border: 'border-indigo-200', pill: 'bg-indigo-100 text-indigo-700' },
  VIII: { bg: 'bg-orange-50',  border: 'border-orange-200', pill: 'bg-orange-100 text-orange-700' },
  X:    { bg: 'bg-cyan-50',    border: 'border-cyan-200',   pill: 'bg-cyan-100 text-cyan-700' },
}

const color = (num) => FAMILY_COLORS[num] || FAMILY_COLORS['I']

function SarfFamilies() {
  const [idx, setIdx] = useState(0)
  const { light } = useHaptic()
  const touchStartX = useRef(null)

  const fam = SARF_FAMILIES[idx]
  const c   = color(fam.familyNum)

  const next = () => { light(); setIdx(i => Math.min(i + 1, SARF_FAMILIES.length - 1)) }
  const prev = () => { light(); setIdx(i => Math.max(i - 1, 0)) }

  useEffect(() => {
    const handle = (e) => {
      if (e.key === 'ArrowRight') next()
      if (e.key === 'ArrowLeft')  prev()
    }
    window.addEventListener('keydown', handle)
    return () => window.removeEventListener('keydown', handle)
  }, [idx])

  const onTouchStart = (e) => { touchStartX.current = e.touches[0].clientX }
  const onTouchEnd   = (e) => {
    if (touchStartX.current === null) return
    const dx = e.changedTouches[0].clientX - touchStartX.current
    // RTL: swipe right → next, swipe left → prev
    if (dx > 50)  next()
    else if (dx < -50) prev()
    touchStartX.current = null
  }

  const FormCell = ({ label, arabic, meaning }) => (
    <div className={`${c.bg} ${c.border} border rounded-xl p-3`}>
      <p className="text-xs text-gray-400 mb-1" dir="ltr">{label}</p>
      <p className="text-xl font-medium text-gray-900 leading-tight">{arabic || '—'}</p>
      {meaning && <p className="text-xs text-gray-500 mt-1" dir="ltr">{meaning}</p>}
    </div>
  )

  const AbsCell = ({ label, arabic }) => (
    <div className="bg-gray-800 border border-gray-700 rounded-xl p-3">
      <p className="text-xs text-gray-500 mb-1" dir="ltr">{label}</p>
      <p className="text-xl font-medium text-gray-100 leading-tight">{arabic || '—'}</p>
    </div>
  )

  return (
    <div className="h-full flex flex-col bg-white">

      {/* Header */}
      <div className="px-4 py-3 border-b border-gray-100 flex items-center justify-between print:hidden">
        <div>
          <h1 className="font-bold text-gray-900">Sarf Families</h1>
          <p className="text-xs text-gray-400" dir="ltr">{idx + 1} of {SARF_FAMILIES.length}</p>
        </div>
        {/* Family jump pills */}
        <div className="flex gap-1 flex-wrap justify-end max-w-[200px]">
          {SARF_FAMILIES.map((f, i) => (
            <button key={f.id} onClick={() => { light(); setIdx(i) }}
              className={`text-xs px-2 py-0.5 rounded-full font-semibold touch-btn ${
                i === idx ? color(f.familyNum).pill : 'bg-gray-100 text-gray-400'
              }`}>
              {f.familyNum}{f.subtypeLabel ? f.subtypeLabel.replace('Pattern','').replace('(','').replace(')','').trim() : ''}
            </button>
          ))}
        </div>
      </div>

      {/* Print View - All Families */}
      <div className="hidden print:block">
        <div className="print-title">
          <h1>Sarf Families - Complete Reference</h1>
        </div>
        
        {/* Alternating Abstract and Actual Forms */}
        <table className="print-table">
          <thead>
            <tr>
              <th>Family</th>
              <th>Type</th>
              <th>Root/Pattern</th>
              <th>Past</th>
              <th>Present</th>
              <th>Masdar (Active)</th>
              <th>Past Pass.</th>
              <th>Present Pass.</th>
              <th>Masdar (Passive)</th>
              <th>Command</th>
              <th>Ism Fa'il</th>
            </tr>
          </thead>
          <tbody>
            {SARF_FAMILIES.map((family) => (
              <>
                {/* Abstract Pattern Row */}
                <tr key={`abstract-${family.id}`} className="abstract-row">
                  <td className="family-cell abstract-family">
                    Family {family.familyNum}
                    {family.subtypeLabel && (
                      <>
                        <br />
                        <span className="subtype">{family.subtypeLabel}</span>
                      </>
                    )}
                  </td>
                  <td className="type-cell">Abstract فعل</td>
                  <td className="pattern-cell" dir="rtl">
                    {family.abstract.past}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.abstract.past}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.abstract.present}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.abstract.masdar}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.abstract.pastPassive || '—'}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.abstract.presentPassive || '—'}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.abstract.masdar}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.abstract.amr}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.abstract.ismFaail}
                  </td>
                </tr>

                {/* Actual Forms Row */}
                <tr key={`actual-${family.id}`} className="actual-row">
                  <td className="family-cell actual-family">
                    Family {family.familyNum}
                    {family.subtypeLabel && (
                      <>
                        <br />
                        <span className="subtype">{family.subtypeLabel}</span>
                      </>
                    )}
                  </td>
                  <td className="type-cell">
                    Actual
                    <br />
                    <span className="meaning">{family.meaning}</span>
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.root}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.forms.past}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.forms.present}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.forms.masdar}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.forms.pastPassive || '—'}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.forms.presentPassive || '—'}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.forms.masdar}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.forms.amr}
                  </td>
                  <td className="arabic-cell" dir="rtl">
                    {family.forms.ismFaail}
                  </td>
                </tr>
              </>
            ))}
          </tbody>
        </table>
      </div>

      {/* Screen View - Single Family */}
      <div className="flex-1 overflow-y-auto px-4 pt-4 pb-safe space-y-3 print:hidden"
           onTouchStart={onTouchStart} onTouchEnd={onTouchEnd}>

        {/* Title card */}
        <div className={`${c.bg} ${c.border} border rounded-2xl p-4`}>
          <div className="flex items-start justify-between">
            <div>
              <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${c.pill}`}>
                Family {fam.familyNum}{fam.subtypeLabel ? ' ' + fam.subtypeLabel : ''}
              </span>
              <p className="text-4xl font-medium mt-2 text-gray-900 leading-tight" dir="rtl">{fam.verb}</p>
              <p className="text-sm text-gray-500 mt-1">{fam.meaning}</p>
            </div>
            <div className="text-right shrink-0 ml-3">
              <p className="text-xs text-gray-400">Root</p>
              <p className="text-lg font-medium text-gray-700 mt-0.5" dir="rtl">{fam.root}</p>
            </div>
          </div>
        </div>

        {/* Active voice */}
        <div>
          <p className="text-xs text-gray-400 uppercase tracking-wide mb-2">Active Voice</p>
          <div className="grid grid-cols-2 gap-2">
            <FormCell label="Past (الماضي)"         arabic={fam.forms.past}     meaning={fam.forms.pastMeaning} />
            <FormCell label="Present (المضارع)"      arabic={fam.forms.present}  meaning={fam.forms.presentMeaning} />
            <FormCell label="Masdar (مصدر)"          arabic={fam.forms.masdar}   meaning={fam.forms.masdarMeaning} />
            <FormCell label="Ism Fa'il (اسم فاعل)"  arabic={fam.forms.ismFaail} meaning={fam.forms.ismFaailMeaning} />
          </div>
        </div>

        {/* Passive voice */}
        {fam.forms.pastPassive && (
          <div>
            <p className="text-xs text-gray-400 uppercase tracking-wide mb-2">Passive Voice</p>
            <div className="grid grid-cols-2 gap-2">
              <FormCell label="Past Passive"    arabic={fam.forms.pastPassive}    meaning={fam.forms.pastPassiveMeaning} />
              <FormCell label="Present Passive" arabic={fam.forms.presentPassive} meaning={fam.forms.presentPassiveMeaning} />
              <FormCell label="Masdar"          arabic={fam.forms.masdar}         meaning={fam.forms.masdarMeaning} />
              {fam.forms.ismMafool
                ? <FormCell label="Ism Maf'ul (اسم مفعول)" arabic={fam.forms.ismMafool} meaning={fam.forms.ismMafoolMeaning} />
                : <div />}
            </div>
          </div>
        )}

        {/* Commands & Zarf */}
        <div>
          <p className="text-xs text-gray-400 uppercase tracking-wide mb-2">Commands & Place</p>
          <div className="grid grid-cols-2 gap-2">
            <FormCell label="Command (أمر)"      arabic={fam.forms.amr}  meaning={fam.forms.amrMeaning} />
            <FormCell label="Prohibition (نهي)"  arabic={fam.forms.nahy} meaning={fam.forms.nahyMeaning} />
          </div>
          <div className="mt-2">
            <FormCell label="Time/Place (ظرف)" arabic={fam.forms.zarf} meaning={fam.forms.zarfMeaning} />
          </div>
        </div>

        {/* Abstract pattern */}
        <div className="bg-gray-900 rounded-xl p-4 space-y-3">
          <p className="text-xs text-gray-400 uppercase tracking-wide">Abstract فَعَلَ Pattern</p>

          {/* Abstract active voice */}
          <div>
            <p className="text-xs text-gray-600 uppercase tracking-wide mb-2">Active Voice</p>
            <div className="grid grid-cols-2 gap-2">
              <AbsCell label="Past (الماضي)"        arabic={fam.abstract.past} />
              <AbsCell label="Present (المضارع)"    arabic={fam.abstract.present} />
              <AbsCell label="Masdar (مصدر)"        arabic={fam.abstract.masdar} />
              <AbsCell label="Ism Fa'il (اسم فاعل)" arabic={fam.abstract.ismFaail} />
            </div>
          </div>

          {/* Abstract passive voice */}
          {fam.abstract.pastPassive && (
            <div>
              <p className="text-xs text-gray-600 uppercase tracking-wide mb-2">Passive Voice</p>
              <div className="grid grid-cols-2 gap-2">
                <AbsCell label="Past Passive"    arabic={fam.abstract.pastPassive} />
                <AbsCell label="Present Passive" arabic={fam.abstract.presentPassive} />
                <AbsCell label="Masdar (مصدر)"   arabic={fam.abstract.masdar} />
                {fam.abstract.ismMafool
                  ? <AbsCell label="Ism Maf'ul (اسم مفعول)" arabic={fam.abstract.ismMafool} />
                  : <div />}
              </div>
            </div>
          )}

          {/* Abstract commands & zarf */}
          <div>
            <p className="text-xs text-gray-600 uppercase tracking-wide mb-2">Commands & Place</p>
            <div className="grid grid-cols-2 gap-2">
              <AbsCell label="Command (أمر)"     arabic={fam.abstract.amr} />
              <AbsCell label="Prohibition (نهي)" arabic={fam.abstract.nahy} />
            </div>
            <div className="mt-2">
              <AbsCell label="Time/Place (ظرف)" arabic={fam.abstract.zarf} />
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default SarfFamilies
