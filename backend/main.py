from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, Integer, String,ForeignKey,Float,func, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker,relationship
from sqlalchemy import Date, Time, DateTime
from datetime import datetime
from math import radians,sin,cos,sqrt,atan2
import traceback
from fastapi import Request
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

INTENTS = {
    "plumber": ["leaky pipe", "water leakage", "clogged drain", "fix tap"],
    "electrician": ["short circuit", "power cut", "fuse issue", "install fan"],
    "cleaning": ["house cleaning", "maid", "dust removal", "vacuum room"],
    "hvac": ["ac not working", "air conditioner", "cooling problem", "repair HVAC"]
}

vectorizer = TfidfVectorizer()
intent_texts = [item for sublist in INTENTS.values() for item in sublist]
intent_labels = [key for key, val in INTENTS.items() for _ in val]
intent_vectors = vectorizer.fit_transform(intent_texts)





ALLOWED_SKILLS = {"plumber", "electrician", "cleaning", "hvac"}


db_url = "postgresql://postgres:Thejaskc123$@localhost/MAC1"
engine = create_engine(db_url)
SessionLocal = sessionmaker(bind=engine, autoflush=False)
Base = declarative_base()

app = FastAPI()

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    age = Column(Integer)
    gender = Column(String)
    email = Column(String, unique=True, index=True)
    password = Column(String)
    role = Column(String)
    fcm_token = Column(String, nullable=True)

class Worker(Base):
    __tablename__ = "workers"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    skill = Column(String)
    experience = Column(Integer)
    latitude = Column(Float) 
    longitude = Column(Float)
    hourly_rate = Column(Float)

    user = relationship("User", back_populates="worker")

User.worker = relationship("Worker", back_populates="user", uselist=False)

class Booking(Base):
    __tablename__ = "bookings"

    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("users.id"))
    worker_id = Column(Integer, ForeignKey("users.id"))
    job_title = Column(String)
    address = Column(String)
    date = Column(Date)
    time = Column(Time)
    status = Column(String,default="pending")
    created_at = Column(DateTime, default=datetime.utcnow)
    time_taken = Column(Float, default=0.0)  
    extra_cost = Column(Float, default=0.0)
    extra_reason = Column(String, default="")

    customer = relationship("User", foreign_keys=[customer_id])
    worker = relationship("User",foreign_keys=[worker_id])

class Rating(Base):
    __tablename__ = "ratings"

    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("users.id"))
    worker_id = Column(Integer, ForeignKey("users.id"))
    rating = Column(Integer)
    review = Column(String)
    timestamp = Column(DateTime, default=datetime.utcnow)

class JobRequest(Base):
    __tablename__ = "job_requests"

    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("users.id"))
    worker_id = Column(Integer, ForeignKey("users.id"))
    description = Column(String)
    preferred_datetime = Column(DateTime)
    status = Column(String, default="pending")
    customer_lat = Column(Float)  
    customer_lon = Column(Float)

    created_at = Column(DateTime, default=datetime.utcnow)

    customer = relationship("User", foreign_keys=[customer_id])
    worker = relationship("User", foreign_keys=[worker_id])

class Notification(Base):
    __tablename__ = "notifications"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    message = Column(String)
    timestamp = Column(DateTime, default=datetime.utcnow)
    read = Column(Boolean, default=False)

    user = relationship("User")



Base.metadata.create_all(bind=engine)


class Signupdata(BaseModel):
    name: str
    age: int
    gender: str
    email: str
    password: str
    role: str

@app.post("/signup")
def signup(data: Signupdata):

    if not data.email.__contains__("@"):
        raise HTTPException(status_code=400, detail="Must be an email")
    
    if data.role == "plumber":
        data.role = "plumbing"
    
    db = SessionLocal()

    excisting_user = db.query(User).filter(User.email == data.email).first()
    if excisting_user:
        raise HTTPException(statuscode= 409,detail = "Email already registered")
    
    new_user= User(
        name = data.name,
        age = data.age,
        gender = data.gender,
        email = data.email,
        password = data.password,
        role = data.role
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    db.close()
    return {"message": "Signup successful","user_id": new_user.id}

class Logindata(BaseModel):
    email: str
    password: str

@app.post("/login")
def login(data: Logindata):
    db = SessionLocal()

    user = db.query(User).filter(User.email == data.email).first()
    db.close()

    if not user:
        raise HTTPException(status_code=401, detail="User Not Found")
    
    if user.password != data.password:
        raise HTTPException(status_code=401, detail="Incorrect Password")
    
    return {
        "message": "Login successful",
        "role": user.role,
        "user_id": user.id
    }

class WorkerInfo(BaseModel):
    user_id: int
    skill: str
    experience: int
    hourly_rate: float

@app.post('/worker_info')
def add_worker_info(data: WorkerInfo):
    db = SessionLocal()

    if data.skill.lower() not in ALLOWED_SKILLS:
        db.close()
        raise HTTPException(
            status_code=400,
            detail=f"Invalid skill. Must be one of: {', '.join(ALLOWED_SKILLS)}"
        )

    existing_worker = db.query(Worker).filter(Worker.user_id == data.user_id).first()

    if existing_worker:
        raise HTTPException(status_code=400, detail="Worker info already exists")
        db.close()
    
    worker = Worker(
        user_id=data.user_id,
        skill=data.skill,
        experience=data.experience,
        hourly_rate=data.hourly_rate
    )
    db.add(worker)
    db.commit()
    db.refresh(worker)
    db.close()

    return{"message": "Worker Profile created successfully"}

@app.get("/worker_profile/{user_id}")
def get_worker_profile(user_id: int):
    db = SessionLocal()
    worker = db.query(Worker).filter(Worker.user_id == user_id).first()

    if not worker:
        db.close()
        raise HTTPException(status_code=404, detail="Worker not found")

    user = db.query(User).filter(User.id == user_id).first()

    db.close()

    return {
        "name": user.name,
        "age": user.age,
        "gender": user.gender,
        "skill": worker.skill,
        "experience": worker.experience,
        "hourly_rate": worker.hourly_rate
    }

class BookingData(BaseModel):
    customer_id: int
    worker_id: int
    job_title: str
    address: str
    date: str   #YYYY-MM-DD
    time: str   #HH:MM



@app.get("/worker/{worker_id}/pending-jobs")
def get_pending_jobs(worker_id: int):
    db = SessionLocal()
    jobs = db.query(Booking).filter(
        Booking.worker_id == worker_id,
        Booking.status == "pending"
    ).order_by(Booking.date, Booking.time).all()

    result = []
    for job in jobs:
        customer = db.query(User).filter(User.id == job.customer_id).first()
        result.append({
            "job_title": job.job_title,
            "address": job.address,
            "date": job.date.strftime("%Y-%m-%d"),
            "time": job.time.strftime("%H:%M"),
            "customer_name": customer.name if customer else "Unknown",
            "booking_id": job.id
        })

    db.close()
    return result

@app.get("/worker/{worker_id}/completed-jobs")
def get_completed_jobs(worker_id:int):
    db = SessionLocal()
    jobs = db.query(Booking).filter(Booking.worker_id == worker_id,Booking.status == "completed").all()
    db.close()

    return [{
        "booking_id": job.id,
        "job-title": job.job_title,
        "address": job.address,
        "date": job.date.strftime("%Y-%m-%d"),
        "time": job.time.strftime("%H:%M"),
    }for job in jobs]

class RatingData(BaseModel):
    customer_id: int
    worker_id: int
    rating: int
    review: str = ""

@app.post('/rate')
def rate_worker(data: RatingData):
    db =SessionLocal()
    if data.rating<1 or data.rating>5:
        raise HTTPException(status_code=400, details="Rating must be between 1 to 5")
    
    new_rating= Rating(
        customer_id=data.customer_id,
        worker_id=data.worker_id,
        rating=data.rating,
        review=data.review
    )
    db.add(new_rating)
    db.commit()
    db.refresh(new_rating)
    db.close()

    return {"message": "rating Succesfully Submitted"}

@app.get("/worker_rating/{worker_id}")
def get_worker_rating(worker_id: int):
    db = SessionLocal()
    avg_rating = (
        db.query(func.avg(Rating.rating)).filter(Rating.worker_id == worker_id).scalar()
    )
    db.close()
    if avg_rating is None:
        return {"average_rating": 0}
    
    return{"average_rating": round(avg_rating,2)}
    
@app.get("/worker/leaderboard")
def get_leaderboard():
    db = SessionLocal()
    results = (
        db.query(User.name, func.avg(Rating.rating).label("avg_rating")).join(Rating, Rating.worker_id == User.id).group_by(User.id).order_by(func.avg(Rating.rating).desc()).limit(5).all()
    )
    db.close()
    return [{
        "name": name, 
        "avg_rating": round(avg_rating, 2)} 
        for name, avg_rating in results]



def calc_distance(lat1,lon1, lat2, lon2):
    R=6371
    dlat=radians(lat2-lat1)
    dlon=radians(lon2-lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)**2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return R*c


@app.get("/customer_profile/{user_id}")
def get_customer_profile(user_id: int):
    db = SessionLocal()
    user = db.query(User).filter(User.id == user_id).first()
    db.close()

    if not user:
        raise HTTPException(status_code = 404, details="User not Found")
    
    return {
        "name": user.name,
        "age": user.age,
        "gender": user.gender,
    }

@app.get("/customer/{user_id}/upcoming-jobs")
def get_upcoming_jobs(user_id: int):
    db = SessionLocal()
    jobs = db.query(Booking).filter(Booking.customer_id == user_id,Booking.status == "pending").order_by(Booking.date, Booking.time).all()
    db.close()

    return [{
        "job-title": job.job_title,
        "address": job.address,
        "date": job.date.strftime("%Y-%m-%d"),
        "time": job.time.strftime("%H:%M"),
    }for job in jobs]

@app.get("/customer/{user_id}/accepted-workers")
def get_accepted_workers(user_id: int):
    db = SessionLocal()
    try:
        offers = (
           db.query(JobRequest, Worker, User)
            .join(Worker, JobRequest.worker_id == Worker.user_id)
            .join(User, Worker.user_id == User.id)
            .filter(JobRequest.customer_id == user_id, JobRequest.status == "accepted")
            .all()
        )

        result = []
        for offer, worker, user in offers:
            if not offers:
                if offer.prefered_datetime is None:
                    continue

            avg_rating = (
                db.query(func.avg(Rating.rating))
                .filter(Rating.worker_id == worker.user_id)
                .scalar()
            ) or 0.0

            distance = calc_distance(
                offer.customer_lat, offer.customer_lon,
                worker.latitude, worker.longitude
            )

            result.append({
            "worker_id": worker.user_id,
            "name": user.name,
            "skill": worker.skill,
            "hourly_rate": worker.hourly_rate,
            "rating": round(avg_rating, 2),
            "distance": round(distance, 2),
            "customer_lat": offer.customer_lat,
            "customer_lon": offer.customer_lon,
            "date" : offer.preferred_datetime.date().isoformat(),
            "time" : offer.preferred_datetime.time().strftime("%H:%M")
        })

        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()

@app.get("/workers/skill/{skill}")
def get_workers_by_skill(skill: str,customer_lat: float, customer_lon: float):
    db = SessionLocal()
    try:
        workers = (
            db.query(Worker, User)
            .join(User, Worker.user_id == User.id)
            .filter(Worker.skill == skill.lower())
            .all()
        )

        result = []
        for worker, user in workers:
            distance = calc_distance(customer_lat,customer_lon,worker.latitude,worker.longitude)
            avg_rating = (
                db.query(func.avg(Rating.rating))
                .filter(Rating.worker_id == worker.user_id)
                .scalar()
            ) or 0.0

            result.append({
                "worker_id": worker.user_id,
                "name": user.name,
                "hourly_rate": worker.hourly_rate,
                "rating": round(avg_rating, 2),
                "distance": round(distance,2)
            })
        result.sort(key=lambda x:x["distance"])
        return result
    finally:
        db.close()

class JobRequestData(BaseModel):
    customer_id: int
    worker_id: int
    description: str
    preferred_datetime: datetime
    customer_lat: float
    customer_lon: float

@app.post("/request_job/")
def request_job(data: JobRequestData):
    db = SessionLocal()
    try:
        job = JobRequest(
            customer_id=data.customer_id,
            worker_id=data.worker_id,
            description=data.description,
            preferred_datetime = data.preferred_datetime,  
            customer_lat=data.customer_lat,
            customer_lon=data.customer_lon
        )
        db.add(job)
        db.commit()
        db.refresh(job)
        worker = db.query(User).filter(User.id == data.worker_id).first()
        return {"message": "Job request submitted", "job_id": job.id}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()

@app.get("/worker/{worker_id}/incoming-requests")
def get_incoming_requests(worker_id: int):
    db = SessionLocal()
    try:
        requests = (
            db.query(JobRequest, User)
            .join(User, JobRequest.customer_id == User.id)
            .filter(JobRequest.worker_id == worker_id, JobRequest.status == "pending")
            .order_by(JobRequest.created_at.desc())
            .all()
        )

        result = []
        for job, customer in requests:
            result.append({
                "job_id": job.id,
                "description": job.description,
                "preferred_datetime": job.preferred_datetime.strftime("%Y-%m-%d %H:%M"),
                "customer_name": customer.name,
            })
        return result
    finally:
        db.close()

@app.post("/job-request/{job_id}/respond")
def respond_to_job(job_id: int, decision: str):
    db = SessionLocal()
    try:
        job = db.query(JobRequest).filter(JobRequest.id == job_id).first()
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        if decision not in ["accepted", "rejected"]:
            raise HTTPException(status_code=400, detail="Invalid decision")

        job.status = decision
        db.commit()
        customer = db.query(User).filter(User.id == job.customer_id).first()
        return {"message": f"Job {decision} successfully"}
    finally:
        db.close()

class BookingCreate(BaseModel):
    customer_id: int
    worker_id: int
    job_title: str
    address: str
    date: str  # 'YYYY-MM-DD'
    time: str  # 'HH:MM'

@app.post("/book")
def create_booking(data: BookingCreate):
    db = SessionLocal()
    try:
        booking = Booking(
            customer_id=data.customer_id,
            worker_id=data.worker_id,
            job_title=data.job_title,
            address=data.address,
            date=datetime.strptime(data.date, "%Y-%m-%d").date(),
            time=datetime.strptime(data.time, "%H:%M").time(),
            status="pending"
        )
        db.add(booking)
        db.commit()
        db.refresh(booking)

        job_request = db.query(JobRequest).filter(
            JobRequest.customer_id == data.customer_id,
            JobRequest.worker_id == data.worker_id,
            JobRequest.status == "accepted"  
            ).first()
        if job_request:
            db.delete(job_request)
            db.commit()
        worker = db.query(User).filter(User.id == data.worker_id).first()
        return {"message": "Booking created successfully", "booking_id": booking.id}

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()

class jobCompleteData(BaseModel):
    booking_id: int
    duration_hours: float
    additional_cost: float
    reason: str

@app.post("/booking/complete")
def complete_booking(data: jobCompleteData):
    db = SessionLocal()
    try:
        booking = db.query(Booking).filter(Booking.id == data.booking_id).first()
        if not booking:
            raise HTTPException(status_code = 404, detail = "Booking not found")
        
        booking.status = "completed"
        booking.time_taken = data.duration_hours
        booking.extra_cost = data.additional_cost
        booking.extra_reason = data.reason
        db.commit()
        db.refresh(booking)
        customer = db.query(User).filter(User.id == booking.customer_id).first()
        return {"message": "Booking marked as completed successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code = 500, detail = str(e))
    finally:
        db.close()

@app.get("/booking/{booking_id}/summary")
def get_booking_summary(booking_id : int):
    db=SessionLocal()
    try:
        booking = db.query(Booking).filter(Booking.id == booking_id).first()
        if not booking:
            raise HTTPException(status_code = 404, detail = "Booking not found")
        
        worker = db.query(User).filter(User.id == booking.worker_id).first()
        hourly_rate = db.query(Worker.hourly_rate).filter(Worker.user_id == booking.worker_id).scalar()
        return {
            "worker_name": worker.name,
            "job_title": booking.job_title,
            "time_taken": booking.time_taken,
            "extra_cost": booking.extra_cost,
            "extra_reason": booking.extra_reason,
            "service_cost": round(hourly_rate * booking.time_taken, 2),
            "commission": round(0.10 * hourly_rate * booking.time_taken, 2),
            "total_cost": round((hourly_rate * booking.time_taken * 1.10) + booking.extra_cost, 2)
        }
    finally:
        db.close()

@app.get("/customer/{user_id}/completed-jobs")
def get_completed_jobs(user_id: int):
    db = SessionLocal()
    jobs = db.query(Booking).filter(
        Booking.customer_id == user_id,
        Booking.status == "completed"
    ).order_by(Booking.date.desc()).all()

    return [{
        "booking_id": job.id, 
        "job-title": job.job_title,
        "worker_id": job.worker_id,
        "address": job.address,
        "date": job.date.strftime("%Y-%m-%d"),
        "time": job.time.strftime("%H:%M"),
    } for job in jobs]

class NotificationData(BaseModel):
    user_id: int
    message: str

@app.post("/chatbot/")
async def chatbot(request: Request):
    data = await request.json()
    message = data.get("message")
    user_lat = float(data.get("lat"))
    user_lon = float(data.get("lon"))

    # Process intent
    msg_vec = vectorizer.transform([message])
    similarity = cosine_similarity(msg_vec, intent_vectors).flatten()
    best_idx = similarity.argmax()
    detected_intent = intent_labels[best_idx]
    
    # Reuse your worker-fetch logic
    db = SessionLocal()
    workers = (
        db.query(Worker, User)
        .join(User, Worker.user_id == User.id)
        .filter(Worker.skill == detected_intent)
        .all()
    )
    results = []
    for worker, user in workers:
        distance = calc_distance(user_lat, user_lon, worker.latitude, worker.longitude)
        avg_rating = (
            db.query(func.avg(Rating.rating))
            .filter(Rating.worker_id == worker.user_id)
            .scalar()
        ) or 0.0

        results.append({
            "worker_id": worker.user_id,
            "name": user.name,
            "hourly_rate": worker.hourly_rate,
            "rating": round(avg_rating, 2),
            "distance": round(distance, 2)
        })
    results.sort(key=lambda x: x["distance"])
    return {
        "intent": detected_intent,
        "workers": results
    }

@app.get("/admin/users")
def get_all_users():
    db = SessionLocal()
    users = db.query(User).all()
    db.close()
    return [{"id": u.id, "name": u.name, "email": u.email, "role": u.role} for u in users]

@app.get("/admin/workers")
def get_all_workers():
    db = SessionLocal()
    workers = (
        db.query(Worker, User)
        .join(User, Worker.user_id == User.id)
        .all()
    )
    result = []
    for worker, user in workers:
        avg_rating = db.query(func.avg(Rating.rating)).filter(Rating.worker_id == worker.user_id).scalar() or 0.0
        result.append({
            "name": user.name,
            "skill": worker.skill,
            "experience": worker.experience,
            "hourly_rate": worker.hourly_rate,
            "rating": round(avg_rating, 2)
        })
    db.close()
    return result

@app.get("/admin/bookings")
def get_all_bookings():
    db = SessionLocal()
    bookings = db.query(Booking).all()
    result = []
    for b in bookings:
        result.append({
            "id": b.id,
            "job_title": b.job_title,
            "status": b.status,
            "customer_id": b.customer_id,
            "worker_id": b.worker_id,
            "date": b.date.strftime("%Y-%m-%d"),
            "time": b.time.strftime("%H:%M"),
        })
    db.close()
    return result

@app.get("/admin/revenue")
def get_total_revenue():
    db = SessionLocal()
    completed_bookings = db.query(Booking).filter(Booking.status == "completed").all()
    revenue = 0
    for b in completed_bookings:
        rate = db.query(Worker.hourly_rate).filter(Worker.user_id == b.worker_id).scalar() or 0.0
        revenue += (rate * b.time_taken * 0.10)
    db.close()
    return {"total_revenue": round(revenue, 2)}




    