package com.sevalink.sevalinkbackend.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.Date;

@Component
public class JwtTokenProvider {
	@Value("${jwt.secret}")
	private String jwtSecret;

	@Value("${jwt.access-token-expiry}")
	private long accessTokenExpiry;

	private SecretKey signingKey() {
		return new SecretKeySpec(jwtSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
	}

	public String generateToken(AuthenticatedUser user) {
		Date now = new Date();
		Date expiry = new Date(now.getTime() + accessTokenExpiry);

		return Jwts.builder()
				.subject(String.valueOf(user.getId()))
				.claim("name", user.getName())
				.claim("email", user.getEmail())
				.claim("phone", user.getPhone())
				.claim("role", user.getRole().name())
				.issuedAt(now)
				.expiration(expiry)
				.signWith(signingKey(), SignatureAlgorithm.HS256)
				.compact();
	}

	public Long getUserIdFromToken(String token) {
		return Long.valueOf(getClaims(token).getSubject());
	}

	public boolean validateToken(String token) {
		try {
			getClaims(token);
			return true;
		} catch (Exception ex) {
			return false;
		}
	}

	private Claims getClaims(String token) {
		Jws<Claims> claimsJws = Jwts.parser()
				.verifyWith(signingKey())
				.build()
				.parseSignedClaims(token);
		return claimsJws.getPayload();
	}
}

