import os
from datetime import datetime
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from models import ActivityHistory, CaptionLog, UnknownPerson, Alert, Child

REPORTS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '../reports'))
os.makedirs(REPORTS_DIR, exist_ok=True)

def generate_pdf_report(title: str, headers: list, data: list, filename: str) -> str:
    filepath = os.path.join(REPORTS_DIR, filename)
    doc = SimpleDocTemplate(filepath, pagesize=letter)
    story = []
    
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'TitleStyle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=22,
        textColor=colors.HexColor('#1E3D59'),
        spaceAfter=15
    )
    subtitle_style = ParagraphStyle(
        'SubtitleStyle',
        parent=styles['Normal'],
        fontSize=10,
        textColor=colors.HexColor('#17B890'),
        spaceAfter=15
    )
    
    story.append(Paragraph(title, title_style))
    story.append(Paragraph(f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", subtitle_style))
    story.append(Spacer(1, 10))
    
    table_data = [headers] + data
    t = Table(table_data)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1E3D59')),
        ('TEXTCOLOR', (0,0), (-1,0), colors.whitesmoke),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE', (0,0), (-1,0), 11),
        ('BOTTOMPADDING', (0,0), (-1,0), 8),
        ('BACKGROUND', (0,1), (-1,-1), colors.HexColor('#F5F7FA')),
        ('GRID', (0,0), (-1,-1), 1, colors.HexColor('#E2E8F0')),
        ('FONTNAME', (0,1), (-1,-1), 'Helvetica'),
        ('FONTSIZE', (0,1), (-1,-1), 9),
        ('PADDING', (0,0), (-1,-1), 5),
    ]))
    
    story.append(t)
    doc.build(story)
    return filepath

def generate_activity_report(db, child_id: int) -> str:
    activities = db.query(ActivityHistory).filter(ActivityHistory.child_id == child_id).all()
    data = []
    for act in activities:
        data.append([act.timestamp[:19], act.action, act.details])
    
    return generate_pdf_report(
        "Basira - Activity History Report",
        ["Timestamp", "Action", "Details"],
        data if data else [["No data", "No data", "No data"]],
        f"activity_report_{child_id}_{int(datetime.now().timestamp())}.pdf"
    )

def generate_detection_report(db, child_id: int) -> str:
    captions = db.query(CaptionLog).filter(CaptionLog.child_id == child_id).all()
    data = []
    for cap in captions:
        data.append([cap.timestamp[:19], cap.model_name, cap.caption, f"{cap.confidence:.2f}", f"{cap.execution_time:.2f}s"])
    
    return generate_pdf_report(
        "Basira - Detection & Caption Report",
        ["Timestamp", "Model", "Caption", "Confidence", "Time"],
        data if data else [["No data", "No data", "No data", "No data", "No data"]],
        f"detection_report_{child_id}_{int(datetime.now().timestamp())}.pdf"
    )

def generate_unknown_report(db, child_id: int) -> str:
    unknowns = db.query(UnknownPerson).filter(UnknownPerson.child_id == child_id).all()
    data = []
    for unk in unknowns:
        data.append([unk.detected_at[:19], unk.face_image_path, "Yes" if unk.is_converted else "No"])
    
    return generate_pdf_report(
        "Basira - Unknown Persons Report",
        ["Detected At", "Image Path", "Converted to Known?"],
        data if data else [["No data", "No data", "No data"]],
        f"unknown_report_{child_id}_{int(datetime.now().timestamp())}.pdf"
    )

def generate_alerts_report(db, child_id: int) -> str:
    alerts = db.query(Alert).filter(Alert.child_id == child_id).all()
    data = []
    for alt in alerts:
        data.append([alt.timestamp[:19], alt.type, alt.message, "Yes" if alt.is_resolved else "No"])
    
    return generate_pdf_report(
        "Basira - Alerts History Report",
        ["Timestamp", "Alert Type", "Message", "Resolved?"],
        data if data else [["No data", "No data", "No data", "No data"]],
        f"alerts_report_{child_id}_{int(datetime.now().timestamp())}.pdf"
    )

def generate_full_child_report(db, child_id: int) -> str:
    child = db.query(Child).filter(Child.id == child_id).first()
    child_name = child.name if child else f"Child {child_id}"
    
    activities = db.query(ActivityHistory).filter(ActivityHistory.child_id == child_id).count()
    captions = db.query(CaptionLog).filter(CaptionLog.child_id == child_id).count()
    unknowns = db.query(UnknownPerson).filter(UnknownPerson.child_id == child_id).count()
    alerts = db.query(Alert).filter(Alert.child_id == child_id).count()
    
    data = [
        ["Total Logged Activities", str(activities)],
        ["Total Generated Captions", str(captions)],
        ["Total Unknown Face Captures", str(unknowns)],
        ["Total Alerts Triggered", str(alerts)]
    ]
    
    return generate_pdf_report(
        f"Basira - Full Summary Report for {child_name}",
        ["Metric", "Value"],
        data,
        f"full_report_{child_id}_{int(datetime.now().timestamp())}.pdf"
    )
