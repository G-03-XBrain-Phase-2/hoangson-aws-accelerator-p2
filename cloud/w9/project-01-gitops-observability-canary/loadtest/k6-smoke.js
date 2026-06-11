import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  vus: 5,
  duration: "1m",
};

export default function () {
  const baseUrl = __ENV.BASE_URL;
  const res = http.get(baseUrl);

  check(res, {
    "status is 200": (r) => r.status === 200,
  });

  sleep(1);
}
