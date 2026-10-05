package com.example.capstone.repository;

import com.example.capstone.domain.place.Place;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PlacesRepository extends JpaRepository<Place, Long> {

    /**
     * 외부 ID로 장소 조회
     */
    Optional<Place> findByExternalId(String externalId);

    /**
     * 장소명으로 검색 (부분 일치)
     */
    @Query("SELECT p FROM Place p WHERE p.placeName LIKE %:keyword% ORDER BY p.searchCount DESC, p.createdAt DESC")
    List<Place> findByPlaceNameContaining(@Param("keyword") String keyword);

    /**
     * 장소명 또는 주소로 검색
     */
    @Query("SELECT p FROM Place p WHERE p.placeName LIKE %:keyword% OR p.address LIKE %:keyword% OR p.roadAddress LIKE %:keyword% ORDER BY p.searchCount DESC")
    List<Place> searchByKeyword(@Param("keyword") String keyword);

    /**
     * 인기 장소 조회 (검색 횟수 기준)
     */
    @Query("SELECT p FROM Place p ORDER BY p.searchCount DESC")
    List<Place> findPopularPlaces();
}

