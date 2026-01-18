# backend/models.py
from sqlalchemy import Column, Integer, String, ForeignKey, Float, Date, Time, DateTime, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
from .database import Base 

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

    
    worker = relationship("Worker", back_populates="user", uselist=False)


class Worker(Base):
    __tablename__ = "workers"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    skill = Column(String)
    experience = Column(Integer)
    latitude = Column(Float)
    longitude = Column(Float)
    hourly_rate = Column(Float)
    money_earned = Column(Float, default=0.0)

    user = relationship("User", back_populates="worker")


class Booking(Base):
    __tablename__ = "bookings"
    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("users.id"))
    worker_id = Column(Integer, ForeignKey("users.id"))
    job_title = Column(String)
    address = Column(String)
    date = Column(Date)
    time = Column(Time)
    status = Column(String, default="pending")
    created_at = Column(DateTime, default=datetime.utcnow)
    time_taken = Column(Float, default=0.0)     
    extra_cost = Column(Float, default=0.0)
    extra_reason = Column(String, default="")

    customer = relationship("User", foreign_keys=[customer_id])
    worker = relationship("User", foreign_keys=[worker_id])


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



