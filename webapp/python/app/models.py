from datetime import datetime

import pydantic


class BaseModel(pydantic.BaseModel):
    model_config = pydantic.ConfigDict(from_attributes=True)


class Chair(BaseModel):
    id: str
    owner_id: str
    name: str
    model: str
    is_active: bool
    access_token: str
    created_at: datetime
    updated_at: datetime


class ChairModel(BaseModel):
    name: str
    speed: int


class ChairLocation(BaseModel):
    id: str
    chair_id: str
    latitude: int
    longitude: int
    created_at: datetime


class User(BaseModel):
    id: str
    username: str
    firstname: str
    lastname: str
    date_of_birth: str
    access_token: str
    invitation_code: str
    created_at: datetime
    updated_at: datetime


class PaymentToken(BaseModel):
    user_id: str
    token: str
    created_at: datetime


class Ride(BaseModel):
    id: str
    user_id: str
    chair_id: str | None
    pickup_latitude: int
    pickup_longitude: int
    destination_latitude: int
    destination_longitude: int
    evaluation: int | None
    created_at: datetime
    updated_at: datetime


class RideStatus(BaseModel):
    id: str
    ride_id: str
    status: str
    created_at: datetime
    app_sent_at: datetime | None = None
    chair_sent_at: datetime | None = None


class Owner(BaseModel):
    id: str
    name: str
    access_token: str
    chair_register_token: str
    created_at: datetime
    updated_at: datetime


class Coupon(BaseModel):
    user_id: str
    code: str
    discount: int
    created_at: datetime
    used_by: str | None
