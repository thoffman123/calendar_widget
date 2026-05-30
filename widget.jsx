/**
 * Week At A Glance — Übersicht Widget
 */

const DATA_FILE = "/Volumes/External_Projects/calendar_widget/week-calendar.json";

export const command = `cat "${DATA_FILE}" 2>/dev/null || echo '{"events":[],"updated":"—"}'`;

export const refreshFrequency = 5 * 60 * 1000;

export const className = `
  top: 20px;
  left: 20px;
  width: 340px;
  font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
  font-size: 12px;
`;

const DAYS_SHORT = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const PALETTE = ['#4c9be8','#34c759','#af52de','#ff6b35','#5ac8fa','#ff3b30'];

function hashColor(str) {
  let h = 0;
  for (let i = 0; i < str.length; i++) h = (h * 31 + str.charCodeAt(i)) & 0xffff;
  return h % PALETTE.length;
}

function formatTime(dtStr) {
  const d = new Date(dtStr);
  const h = d.getHours(), m = d.getMinutes();
  const ampm = h >= 12 ? 'PM' : 'AM';
  const hh = h % 12 || 12;
  return hh + (m ? ':' + String(m).padStart(2,'0') : '') + ' ' + ampm;
}

function groupByDay(events, today) {
  const buckets = [[], [], [], [], [], [], []];
  for (let i = 0; i < events.length; i++) {
    const evt = events[i];
    if (evt.allDay) {
      const s = new Date(evt.start + 'T00:00:00');
      const e = evt.end ? new Date(evt.end + 'T00:00:00') : s;
      for (let d = 0; d < 7; d++) {
        const day = new Date(today);
        day.setDate(today.getDate() + d);
        if (day >= s && day < e) buckets[d].push(evt);
      }
    } else {
      const s = new Date(evt.start);
      const d = Math.floor((s - today) / 86400000);
      if (d >= 0 && d < 7) buckets[d].push(evt);
    }
  }
  return buckets;
}

export const render = ({ output, error }) => {
  if (error) {
    return (
      <div style={{background:'rgba(0,0,0,0.7)',padding:'10px',borderRadius:'8px',color:'#ff3b30'}}>
        Error loading widget
      </div>
    );
  }

  var data;
  try { data = JSON.parse(output); }
  catch(e) {
    return (
      <div style={{background:'rgba(0,0,0,0.7)',padding:'10px',borderRadius:'8px',color:'#ff3b30'}}>
        JSON parse error
      </div>
    );
  }

  const today = new Date();
  today.setHours(0,0,0,0);
  const end6 = new Date(today);
  end6.setDate(today.getDate() + 6);

  const sameMonth = today.getMonth() === end6.getMonth();
  const weekLabel = sameMonth
    ? MONTHS[today.getMonth()] + ' ' + today.getDate() + '–' + end6.getDate()
    : MONTHS[today.getMonth()] + ' ' + today.getDate() + ' – ' + MONTHS[end6.getMonth()] + ' ' + end6.getDate();

  const buckets = groupByDay(data.events || [], today);

  const containerStyle = {
    background: 'rgba(15,15,20,0.88)',
    borderRadius: '14px',
    padding: '12px 12px 8px',
    border: '1px solid rgba(255,255,255,0.1)',
    boxShadow: '0 4px 24px rgba(0,0,0,0.6)',
    color: '#f0f0f0',
  };

  const days = [];
  for (let i = 0; i < 7; i++) {
    const dayDate = new Date(today);
    dayDate.setDate(today.getDate() + i);
    const isToday = (i === 0);
    const evts = buckets[i];

    const eventItems = evts.length === 0
      ? <div style={{color:'rgba(255,255,255,0.25)',fontStyle:'italic'}}>No events</div>
      : evts.map((evt, j) => {
          const color = evt.isDayforce ? '#ff9f0a' : PALETTE[hashColor(evt.title || '')];
          const meta = evt.allDay ? 'All day'
            : (evt.start ? formatTime(evt.start) + (evt.end ? ' – ' + formatTime(evt.end) : '') : '');
          return (
            <div key={j} style={{display:'flex',alignItems:'flex-start',gap:'6px',marginBottom:'3px'}}>
              <div style={{width:'7px',height:'7px',borderRadius:'50%',background:color,flexShrink:0,marginTop:'3px'}} />
              <div style={{flex:1,minWidth:0}}>
                <div style={{fontWeight:'600',whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis',color:'rgba(255,255,255,0.9)'}}>
                  {evt.title}
                  {evt.isDayforce && <span style={{fontSize:'9px',fontWeight:'700',background:'rgba(255,159,10,0.2)',color:'#ff9f0a',padding:'0 3px',borderRadius:'3px',marginLeft:'4px'}}>B&amp;N</span>}
                </div>
                {meta ? <div style={{fontSize:'11px',color:'rgba(255,255,255,0.4)'}}>{meta}</div> : null}
              </div>
            </div>
          );
        });

    days.push(
      <div key={i} style={{
        display: 'flex',
        alignItems: 'flex-start',
        gap: '8px',
        padding: '6px 6px',
        borderRadius: '9px',
        marginBottom: '3px',
        background: isToday ? 'rgba(0,113,227,0.2)' : 'rgba(255,255,255,0.04)',
        border: isToday ? '1px solid rgba(0,113,227,0.4)' : '1px solid transparent',
      }}>
        <div style={{width:'36px',textAlign:'center',flexShrink:0}}>
          <div style={{fontSize:'9px',fontWeight:'700',textTransform:'uppercase',letterSpacing:'0.6px',color: isToday ? '#4c9be8' : 'rgba(255,255,255,0.35)'}}>
            {DAYS_SHORT[dayDate.getDay()]}
          </div>
          <div style={{fontSize:'19px',fontWeight:'700',color: isToday ? '#4c9be8' : 'rgba(255,255,255,0.8)',lineHeight:'1.1'}}>
            {dayDate.getDate()}
          </div>
        </div>
        <div style={{width:'1px',background:'rgba(255,255,255,0.09)',alignSelf:'stretch',flexShrink:0}} />
        <div style={{flex:1,minWidth:0,paddingTop:'1px'}}>
          {eventItems}
        </div>
      </div>
    );
  }

  return (
    <div style={containerStyle}>
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'baseline',marginBottom:'9px',paddingBottom:'8px',borderBottom:'1px solid rgba(255,255,255,0.09)'}}>
        <span style={{fontSize:'13px',fontWeight:'700',color:'#fff'}}>Week at a Glance</span>
        <div style={{textAlign:'right'}}>
          <div style={{fontSize:'10px',color:'rgba(255,255,255,0.35)'}}>{weekLabel}</div>
          <div style={{fontSize:'10px',color:'rgba(255,159,10,0.7)'}}>synced: {data.updated}</div>
        </div>
      </div>
      {days}
    </div>
  );
};
