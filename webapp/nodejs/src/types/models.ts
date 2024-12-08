export type Chair = {
  id: string;
  ownerId: string;
  name: string;
  is_active: boolean;
  access_token: string;
  created_at: Date;
  updated_at: Date;
};

export type ChairModel = {
  name: string;
  speed: number;
};

export type ChairLocation = {
  id: string;
  chair_id: string;
  latitude: number;
  longitude: number;
  created_at: Date;
};

export type User = {
  id: string;
  username: string;
  firstname: string;
  lastname: string;
  date_of_birth: string;
  access_token: string;
  invitation_code: string;
  created_at: Date;
  updated_at: Date;
};

export type PaymentToken = {
  user_id: string;
  token: string;
  created_at: Date;
};

export type Ride = {
  id: string;
  user_id: string;
  chair_id: string;
  pickup_latitude: number;
  pickup_longitude: number;
  destination_latitude: number;
  destination_longitude: number;
  evaluation: number | null;
  created_at: Date;
  updated_at: Date;
};

export type RideStatus = {
  id: string;
  ride_id: string;
  status: string;
  created_at: Date;
};

export type Owner = {
  id: string;
  name: string;
  access_token: string;
  chair_register_token: string;
  created_at: Date;
  updated_at: Date;
};

export type Coupon = {
  user_id: string;
  code: string;
  discount: number;
  created_at: Date;
  used_by: string | null;
};

export type Coordinate = {
  latitude: number;
  longitude: number;
};
